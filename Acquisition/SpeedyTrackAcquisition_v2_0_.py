import pylablib
pylablib.par["devices/dlls/andor_sdk2"] = "C:/Program Files/Andor SOLIS"
from pylablib.devices import Andor
from pylablib.devices.Andor.atmcd32d_lib import wlib as lib
import numpy as np
import time
import pyqtgraph as pg
from pyqtgraph.Qt import QtCore
import sys
import PyQt5
from PyQt5.QtGui import *
from PyQt5.QtWidgets import *
from PyQt5.QtCore import *
print('done import')

fractioncpu=0.5; #percent of cpu available to SpeedyTrack 

## General camera parameters. See Andor SDK2 for details  
fanmode="full"
settemp=-80
liveexptime=0.1
triggermode='int'
hsspeed=0
preamp=2
VSamp=4
VSspeed=1

#setting up some default variables...
savestatus=0
writing=0
camind=0
exttrig=0
GUIstart=time.time()

filename=".fits"
filenamedax=".dax"
filenameinf=".inf"
filenametime="_time.txt"
fileframes=0

numberframes=10
shiftheight=30
numshift=33
offset=512-shiftheight
exptime=2*1e-3
data=np.random.rand(numberframes, shiftheight*numshift, 512)
i=0
livestatus=True
pg.setConfigOptions(imageAxisOrder='row-major')
scalemin=0
scalemax=52000
autoscalecont=0
writing=0

class AcquisitionSignals(QObject):
    
    finished = pyqtSignal()
    error = pyqtSignal(tuple)
    result = pyqtSignal(object)
    progress = pyqtSignal(int)

class Worker(QRunnable):
    
    def __init__(self, fn, *args, **kwargs):
        super(Worker, self).__init__()
        self.fn = fn
        self.args = args
        self.kwargs = kwargs
        self.signals = AcquisitionSignals()
        self.kwargs['progress_callback'] = self.signals.progress

    @pyqtSlot()
    def run(self):
        try:
            result = self.fn(*self.args, **self.kwargs)
        except:
            pass
            #traceback.print_exc()
            #exctype, value = sys.exc_info()[:2]
            #self.signals.error.emit((exctype, value, traceback.format_exc()))
        else:
            self.signals.result.emit(result)  
        finally:
            self.signals.finished.emit() 

class MainWindow(PyQt5.QtWidgets.QMainWindow):

    def __init__(self, *args, **kwargs):
        super(MainWindow, self).__init__(*args, **kwargs)

# --- GUI design and setup ---
        
        self.FKview=pg.ImageView(discreteTimeLine=True)

        self.liveimg=pg.ImageView(discreteTimeLine=True)

        numcores=QThread.idealThreadCount()
        self.threadpool = QThreadPool()
        self.threadpool.setMaxThreadCount(round(fractioncpu*numcores))
        print("Multithreading with maximum %d threads" % self.threadpool.maxThreadCount())
        
        self.StartFKButton= PyQt5.QtWidgets.QPushButton("Start SpeedyTrack Acquisition")
        self.StopFKButton= PyQt5.QtWidgets.QPushButton("Stop SpeedyTrack Acquisition")

        self.trigset=PyQt5.QtWidgets.QCheckBox("Ext. trigger       ")
        self.trigset.setChecked(False)
        self.trigset.stateChanged.connect(self.trigsetchange)
        self.setheightlabel=PyQt5.QtWidgets.QLabel()
        self.setheightlabel.setText("Shift height (pixels)")
        self.setheightlabel.setAlignment(QtCore.Qt.AlignRight)
        self.setheight=PyQt5.QtWidgets.QSpinBox()
        self.setheight.setMaximum(600)
        self.setheight.valueChanged.connect(self.setFKheight)
        self.setshiftlabel=PyQt5.QtWidgets.QLabel()
        self.setshiftlabel.setText("Num. shifts")
        self.setshiftlabel.setAlignment(QtCore.Qt.AlignRight)
        self.setnumshift=PyQt5.QtWidgets.QSpinBox()
        self.setnumshift.setMaximum(2000)
        self.setnumshift.valueChanged.connect(self.setFKnumshift)

        FKparamslayout = PyQt5.QtWidgets.QHBoxLayout()
        FKparamslayout.addWidget(self.trigset)
        FKparamslayout.addWidget(self.setheightlabel)
        FKparamslayout.addWidget(self.setheight)
        FKparamslayout.addWidget(self.setshiftlabel)
        FKparamslayout.addWidget(self.setnumshift)

        self.autoscaleonce= PyQt5.QtWidgets.QPushButton("Autoscale once")
        self.autoscalecont=PyQt5.QtWidgets.QCheckBox("Autoscale continuously")
        self.autoscalecont.setChecked(False)
        self.autoscalecont.stateChanged.connect(self.Autoscalecontinuousset)
        self.autoscaleonce.clicked.connect(self.Autoscaleonceset)
        
        self.StartLiveButton= PyQt5.QtWidgets.QPushButton("Start Live")
        self.StopLiveButton= PyQt5.QtWidgets.QPushButton("Stop Live")
        
        ##connect cameras control
        camcontrollayout=PyQt5.QtWidgets.QHBoxLayout()
        self.selectcamlabel=PyQt5.QtWidgets.QLabel()
        self.selectcamlabel.setText("Select Camera index")
        self.camdropdown=PyQt5.QtWidgets.QComboBox()
        self.camdropdown.addItems(['0', '1'])
        self.camconnect= PyQt5.QtWidgets.QPushButton("Connect Camera")
        self.camdropdown.currentIndexChanged.connect(self.camindexchange)
        self.camconnect.clicked.connect(self.connectcam)
        camcontrollayout.addWidget(self.selectcamlabel)
        camcontrollayout.addWidget(self.camdropdown)
        camcontrollayout.addWidget(self.camconnect)
        
        self.savecontrol=PyQt5.QtWidgets.QCheckBox("Save Movie?")
        self.savecontrol.setChecked(False)
        self.savecontrol.stateChanged.connect(self.SaveStatus)

        
        layout = PyQt5.QtWidgets.QVBoxLayout()

        layout1 = PyQt5.QtWidgets.QVBoxLayout()
    
        liveoptionslayout=PyQt5.QtWidgets.QHBoxLayout()
        liveoptionslayout.addWidget(self.savecontrol)
        liveoptionslayout.addWidget(self.autoscalecont)
        liveoptionslayout.addWidget(self.autoscaleonce)

        camconnectlayout=PyQt5.QtWidgets.QHBoxLayout()
        
        
        layout1.addWidget(self.FKview)
        layout1.addWidget(self.StartFKButton)
        layout1.addLayout(FKparamslayout)
        FKwidget=PyQt5.QtWidgets.QWidget()
        FKwidget.setLayout(layout1)

        layout2 = PyQt5.QtWidgets.QVBoxLayout()
        layout2.addLayout(camcontrollayout)
        layout2.addWidget(self.liveimg)
        layout2.addLayout(liveoptionslayout)
        layout2.addWidget(self.StartLiveButton)
        layout2.addWidget(self.StopLiveButton)
        livewidget=PyQt5.QtWidgets.QWidget()
        livewidget.setLayout(layout2)
        
        splitter = PyQt5.QtWidgets.QSplitter(QtCore.Qt.Horizontal)
        splitter.addWidget(livewidget)
        splitter.addWidget(FKwidget)
        splitter.setStretchFactor(1, 1)
        splitter.setSizes([700, 550])
        layoutimagebar=PyQt5.QtWidgets.QHBoxLayout()
        layoutimagebar.addWidget(splitter)
        imagewidget=PyQt5.QtWidgets.QWidget()
        imagewidget.setLayout(layoutimagebar)
        
        self.shuttercontrol=PyQt5.QtWidgets.QCheckBox("Shutter open:")
        self.shuttercontrol.setChecked(False)
        self.shuttercontrol.stateChanged.connect(self.switchshutter)
        self.tempstatus=PyQt5.QtWidgets.QLabel()
        self.tempstatus.setText("Temperature: ")
        self.fanstatus=PyQt5.QtWidgets.QLabel()
        self.fanstatus.setText("Fan Status: ")
        self.acquisitionstatus=PyQt5.QtWidgets.QLabel()
        self.acquisitionstatus.setText("Acq. Status")
        
        layoutstatusbar=PyQt5.QtWidgets.QHBoxLayout()
        layoutstatusbar.addWidget(self.shuttercontrol)
        layoutstatusbar.addWidget(self.tempstatus)
        layoutstatusbar.addWidget(self.fanstatus)
        #layoutstatusbar.addWidget(self.acquisitionstatus)
        statuswidget=PyQt5.QtWidgets.QWidget()
        statuswidget.setLayout(layoutstatusbar)
        vsplitter=PyQt5.QtWidgets.QSplitter(QtCore.Qt.Vertical)
        vsplitter.addWidget(imagewidget)
        vsplitter.addWidget(statuswidget)
        vsplitter.setStretchFactor(1, 1)
        vsplitter.setSizes([1000, 10])
        
        self.setframenumber=PyQt5.QtWidgets.QSpinBox()
        self.setframenumber.setMaximum(99999)
        self.setframenumber.valueChanged.connect(self.setframes)

        self.setgain=PyQt5.QtWidgets.QSpinBox()
        self.setgain.setMaximum(1000)
        self.setgain.valueChanged.connect(self.setgainval)

        self.setexp=PyQt5.QtWidgets.QDoubleSpinBox()
        self.setexp.setMaximum(9999999)
        self.setexp.valueChanged.connect(self.setexptime)
        
        self.setpath=PyQt5.QtWidgets.QLineEdit()
        self.setpath.textEdited.connect(self.settingfilename)
        
        self.setfilebase=PyQt5.QtWidgets.QLineEdit()
        self.setfilebase.textEdited.connect(self.settingfilename)
        
        self.setiteration=PyQt5.QtWidgets.QLineEdit()
        self.setiteration.textEdited.connect(self.settingfilename)
        
        layoutsettingsbar=PyQt5.QtWidgets.QHBoxLayout()

        self.filenamelabel=PyQt5.QtWidgets.QLabel("File path and name:")
        self.framenumberlabel=PyQt5.QtWidgets.QLabel("Number of frames:")
        self.explabel=PyQt5.QtWidgets.QLabel("Exposure time (us):")
        self.gainlabel=PyQt5.QtWidgets.QLabel("EMCCD gain:")

        layoutsettingsbar.addWidget(self.gainlabel)
        layoutsettingsbar.addWidget(self.setgain)
        layoutsettingsbar.addWidget(self.explabel)
        layoutsettingsbar.addWidget(self.setexp)
        layoutsettingsbar.addWidget(self.framenumberlabel)
        layoutsettingsbar.addWidget(self.setframenumber)
        layoutsettingsbar.addWidget(self.filenamelabel)
        layoutsettingsbar.addWidget(self.setpath)
        layoutsettingsbar.addWidget(self.setfilebase)
        layoutsettingsbar.addWidget(self.setiteration)
        
        layout.addWidget(vsplitter)
        layout.addLayout(layoutsettingsbar)
        
        widget = PyQt5.QtWidgets.QWidget()
        widget.setLayout(layout)
        self.setCentralWidget(widget)
        
        self.StartFKButton.clicked.connect(self.AcquisitionStart)
        
        self.StartLiveButton.clicked.connect(self.LiveStart)
        self.StopLiveButton.clicked.connect(self.LiveStop)

        self.img = pg.ImageItem(border='w')


# -- functions to control GUI interactions --
        
    def camindexchange(self, index):
        global camind
        camind=index

    def trigsetchange(self, state):
        global exttrig
        if state == PyQt5.QtCore.Qt.Checked:
            exttrig=1
        else:
            exttrig=0

    def settingfilename(self):
        global filename, filenamedax, filenameinf, fileframes, filenametime
        filename=str(self.setpath.text())+str(self.setfilebase.text())+str(self.setiteration.text())+".fits"
        filenamedax=str(self.setpath.text())+str(self.setfilebase.text())+str(self.setiteration.text())+".dax"
        filenameinf=str(self.setpath.text())+str(self.setfilebase.text())+str(self.setiteration.text())+".inf"
        filenametime=str(self.setpath.text())+str(self.setfilebase.text())+str(self.setiteration.text())+"_time.txt"
        fileframes=0
        #print(filename)

    def setframes(self, n):
        global numberframes
        numberframes=n
        #print(numberframes)

    def updatestatusbar(self, progress_callback):
        while cam.is_opened():
            self.tempstatus.setText("Temperature: "+ str(cam.get_temperature()))
            self.fanstatus.setText("Fan Status: "+ str(cam.get_fan_mode()))
            time.sleep(1)
        self.tempstatus.setText("Temperature: ")
        self.fanstatus.setText("Fan Status: ")

    def updatestatusbarthread(self):
        worker = Worker(self.updatestatusbar) 
        self.threadpool.start(worker)
        
    def setgainval(self, n):
        cam.set_EMCCD_gain(n)
        #print(cam.get_EMCCD_gain())

    def setexptime(self, n):
        global exptime
        exptime=n*1e-6
        lib.SetFastKineticsEx(shiftheight, numshift, exptime, 4, 1, 1, 512-shiftheight)
        #print(exptime)

    def setFKheight(self, n):
        global shiftheight
        shiftheight=n
        lib.SetFastKineticsEx(shiftheight, numshift, exptime, 4, 1, 1, 512-shiftheight)
        #print(shiftheight)

    def setFKnumshift(self, n):
        global numshift
        numshift=n
        lib.SetFastKineticsEx(shiftheight, numshift, exptime, 4, 1, 1, 512-shiftheight)
        #print(numshift)
        
    def switchshutter(b, state):
        if state == PyQt5.QtCore.Qt.Checked:
            cam.setup_shutter('open')
            print(cam.get_shutter())
        else:
            cam.setup_shutter('closed')
            print(cam.get_shutter())

#--- function to connect camera ---
    def connectcam(self):
        global camind, cam
        try:
            cam.close()
        except:
            print(" ")
        try:
            cam = Andor.AndorSDK2Camera(camind)
            print(cam.get_device_info()) 
            cam.set_fan_mode(fanmode)
            cam.set_temperature(settemp)
            print (cam.get_temperature())
            cam.set_EMCCD_gain(0)
            cam.set_exposure(liveexptime)
            cam.set_trigger_mode(triggermode)
            cam.set_amp_mode(channel=None, oamp=0, hsspeed=hsspeed, preamp=preamp)
            print(cam.get_amp_mode(full=True))
            lib.SetVSAmplitude(VSamp)
            cam.set_vsspeed(VSspeed)
            self.updatestatusbarthread()

          
            
        except Exception as error:
            print("Unable to connect to camera:", error)

#--- functions to control data display ---
    
    def updateData(self, n): #Speedytrack data display and saving
        global img, data, frame1, filenamedax, writing, file2
        writing=1
        self.FKview.setImage(data)
        self.FKview.setCurrentIndex(n)
        writing=1
        #file2=open(filenamedax, 'ab')
        file2.write(frame1.tobytes(order='a'))
        #file2.close
        writing=0

    def updateLiveData(self, frame): #live video display
        global currentframe, autoscalecont, scalemin, scalemax 
        if autoscalecont==0:
            self.liveimg.setImage(currentframe, autoLevels=False, autoHistogramRange=False)
            self.liveimghist=self.liveimg.getHistogramWidget()
            self.liveimghist.setHistogramRange(scalemin, scalemax, padding=0.1)
            self.liveimg.setLevels(scalemin, scalemax)
        else:
            self.liveimg.setImage(currentframe, autoLevels=True, autoHistogramRange=True)

#--- functions to run data acquisition ---
    def runFKacquisition(self, progress_callback): #SpeedyTrack acquisition 
        global numberframes, cam, data, shiftheight, numshift, filename, offset, filenamedax, filenametime, fileframes, writing, livestatus, exttrig, frame1, file2
        print ("starting acquisition...")
        file2=open(filenamedax, 'ab')
        livestatus=True
        totalstart=0
        totalacq=0
        totaltrans=0
        t0=time.time()
        data=np.zeros((numberframes, shiftheight*numshift, 512), dtype='uint16') #>u2 : unsigned 16bit int, big endian
        frametimes=np.zeros(numberframes, dtype="float")
        if exttrig:
            lib.SetTriggerMode(1)
        else:
            lib.SetTriggerMode(0)
            
        lib.SetAcquisitionMode(4)
        lib.SetFastKineticsEx(shiftheight, numshift, exptime, 4, 1, 1, 512-shiftheight)
        print(lib.GetReadOutTime())
        print(lib.GetAcquisitionTimings())
        print(lib.GetStatus())
        #lib.EnableKeepCleans(0)
        
        


        for currentframe in range(numberframes):
            if livestatus==True:
                tstart=time.time()
                lib.StartAcquisition()
                tstart1=time.time()
                while lib.GetStatus()==20072:
                    if livestatus==False:
                        print('stopping acquisition...')
                        try:
                            lib.AbortAcquisition()
                            print(lib.GetStatus())
                        finally:
                            break
                    #time.sleep(0.00000000001)
                if livestatus==False:
                    try: lib.AbortAcquisition()
                    finally:
                        break
                tacquire=time.time()
                im=self.readFKframes((512, shiftheight), (1,numshift))
            
                frametimes[currentframe]=tacquire-GUIstart
                ttransfer=time.time()
                writestart=time.time()
                frame=np.array(im[0])
                frame.resize(shiftheight*numshift, 512)
                frame=np.flip(frame,0)
                data[currentframe,:,:]=frame
                frame1=frame
                #frame1=np.transpose(frame, (1,0));
                #frame1=np.flip(frame1, 1);
                #print('acq')
                #while writing==1:
                 #   time.sleep(0.00000000001)
                progress_callback.emit(currentframe)
                totalstart=totalstart+(tstart1-tstart)
                totalacq=totalacq+(tacquire-tstart1)
                totaltrans=totaltrans+(ttransfer-tacquire)
            else:
                break
        print("tstart"+str(totalstart))
        print("tacquire"+str(totalacq))
        print("ttransfer"+str(totaltrans))
        print(t0-time.time())
        fileframes=fileframes+numberframes

        #print(frametimes)
        
        file4=open(filenametime, 'a')
        np.savetxt(file4, frametimes, fmt='%1.5f', newline='\n')
        file4.write("\n")
        file4.close()

        file3=open(filenameinf, 'w')
        str1='data type = 16 bit integers (binary, little endian)'+'\n'
        str2='frame dimensions = 512 x '+ str(shiftheight*numshift) +'\n'
        str3='number of frames = ' +str(fileframes)+'\nbinning = 1 x 1\n'
        str4='x_start = 1\nx_end = 512\ny_start = 1\ny_end = ' +str(shiftheight*numshift)
        file3.write(str1)
        file3.write(str2)
        file3.write(str3)
        file3.write(str4)
        file3.close
        
        print(writing)
##        while writing==1:
##                    time.sleep(0.00000000001)
##        writet=time.time()
##        file2=open(filenamedax, 'ab')
##        print('open '+str(writet-time.time()))
##        file2.write(data.tobytes())
##        print('writing '+str(writet-time.time()))
##        file2.close
        writing=0
        print(writing)
        file2.close()
        print("Done.")

    #-- get speedytrack data from camera
    def readFKframes(self, dim, rng):
        rawdata=lib.GetImages16(rng[0],rng[1], dim[0]*dim[1]*numshift)
        return list(rawdata)

    #-- run camera live view
    def runLiveView(self, progress_callback):
        global livestatus, currentframe, savestatus, numberframes, autoscalecont, frame, writing
        livestatus=True
        savesetup=0
        currentframe=np.zeros((512, 512), dtype="uint16")
        print ("starting acquisition...")
        t0=time.time()
        lib.SetTriggerMode(0)
        if savestatus==1:
            filenameim=str(self.setpath.text())+"image_"+str(self.setfilebase.text())+str(self.setiteration.text())+".fits"
            filenamedaximag=str(self.setpath.text())+"image_"+str(self.setfilebase.text())+str(self.setiteration.text())+".dax"
            filenameinfimag=str(self.setpath.text())+"image_"+str(self.setfilebase.text())+str(self.setiteration.text())+".inf"
            data=np.zeros((numberframes, 512, 512), dtype="uint16")
            savesetup=1
        cam.enable_frame_transfer_mode()
        cam.set_exposure(liveexptime)
        cam.setup_cont_mode()
        #print(cam.get_cont_mode_parameters())
        cam.start_acquisition()
        currentframenum=0
        while livestatus==True:
            #print(livestatus)
            time.sleep(0.01)
            im=cam.read_newest_image()
            #print(im)
            if im is None:
                continue
            else:
                frame=np.array(im)
                #print (type(frame))
                #frame.resize(512, 512)
                #print(currentframe)
                frame=np.flip(frame,0)
                currentframe=frame
                progress_callback.emit(frame)
                if savestatus==1:
                    if savesetup==1:
                        data[currentframenum,:,:]=frame
                        currentframenum=currentframenum+1
                        if currentframenum>=numberframes:
                            cam.stop_acquisition()
                            livestatus=False
                            break
                    else:
                        filenameim=str(self.setpath.text())+"image_"+str(self.setfilebase.text())+str(self.setiteration.text())+".fits"
                        filenamedaximag=str(self.setpath.text())+"image_"+str(self.setfilebase.text())+str(self.setiteration.text())+".dax"
                        filenameinfimag=str(self.setpath.text())+"image_"+str(self.setfilebase.text())+str(self.setiteration.text())+".inf"
                        data=np.zeros((numberframes, 512, 512), dtype="uint16")
                        savesetup=1
                        
        cam.stop_acquisition()
        if savestatus==1:
            #data=np.transpose(data, (0,2,1));
            while writing==1:
                    time.sleep(0.00000000001)
            file3=open(filenameinfimag, 'w')
            str1='data type = 16 bit integers (binary, little endian)'+'\n'
            str2='frame dimensions = '+ '512 x 512 \n'
            str3='number of frames = ' +str(numberframes)+'\nbinning = 1 x 1\nx_start = 1\n x_end = 512\ny_start = 1\n y_end = 512\n'
            file3.write(str1)
            file3.write(str2)
            file3.write(str3)
            file3.close
            file2=open(filenamedaximag, 'wb')
            file2.write(data.tobytes(order='a'))
            file2.close
            writing=0
        print("Stopped")


    def LiveStart(self):
        global livestatus, savestatus
        livestatus=True
        worker = Worker(self.runLiveView) 
        worker.signals.progress.connect(self.updateLiveData)
        self.threadpool.start(worker)

    def LiveStop(self):
        global livestatus 
        livestatus=False

    def SaveStatus(self, state):
        global savestatus
        if state == PyQt5.QtCore.Qt.Checked:
            savestatus=1
        else:
            savestatus=0

    def writeframe(self, imagedata):
        global writing, filenamedax
        try:
            print('startwriting')
            
            file2.write(imagedata.tobytes())
            
            print('endwriting')
            writing=0
        except:
            pass

    def writeframe1(self, n, file2):
        global writing, filenamedax, frame1
        try:
            #print('startwriting')
            writing=1
            #file2=open(filenamedax, 'ab')
            file2.write(frame1.tobytes())
            #file2.close
            #print('endwriting')
            writing=0
        except:
            pass

    def AcquisitionStart(self):
        global writing, filenamedax
        
        worker = Worker(self.runFKacquisition) 
        worker.signals.progress.connect(self.updateData)
        #worker.signals.progress.connect(self.writeframe1)
        
        print ("starting acquisition with threading...")
        self.threadpool.start(worker)
        #file2.close

    def RunSave(self):
        global frame
        print('runsave')
        try:
            worker1 = Worker(self.writeframe(frame))
            print('workerset')
            self.threadpool.start(worker1)
        except:
            pass

    def Autoscaleonceset(self):
        global frame, scalemin, scalemax
        scalemin=np.min(frame)
        scalemax=np.max(frame)
        self.liveimghist=self.liveimg.getHistogramWidget()
        self.liveimghist.setHistogramRange(scalemin, scalemax, padding=0.1)
        
        #self.liveimg = pg.ImageView(levels=(minval, maxval), autoLevels=False)

        
    def Autoscalecontinuousset(self, state):
        global autoscalecont, scalemin, scalemax
        if state == PyQt5.QtCore.Qt.Checked:
            autoscalecont=1
            self.liveimg.autoLevels
        else:
            autoscalecont=0
            scalemin=np.min(frame)
            scalemax=np.max(frame)
            
    def closeEvent(self, *args, **kwargs):
        super(PyQt5.QtWidgets.QMainWindow, self).closeEvent(*args, **kwargs)
        cam.setup_shutter('closed')
        self.liveimg.close()
        self.FKview.close()
        cam.close()
        print ("Goodbye")
        

app = PyQt5.QtWidgets.QApplication(sys.argv)
w = MainWindow()
w.setWindowTitle("SpeedyTrack acquisition")
w.show()
w.resize(1400, 900)
sys.exit(app.exec_())




