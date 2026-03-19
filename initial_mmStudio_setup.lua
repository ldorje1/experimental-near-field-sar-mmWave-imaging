
------------------------------ CONFIGURATIONS ----------------------------------
-- Use "DCA1000" for working with DCA1000
capture_device  = "DCA1000"

-- RS232 COM Port number
uart_com_port   = 4
-- RS232 connection baud rate
baudrate        = 921600
-- Timeout in ms
timeout         = 1000

-- BSS firmware
bss_path        = "C:\\ti\\mmwave_studio_02_01_01_00\\rf_eval_firmware\\radarss\\xwr18xx_radarss.bin"
-- MSS firmware
mss_path        = "C:\\ti\\mmwave_studio_02_01_01_00\\rf_eval_firmware\\masterss\\xwr18xx_masterss.bin"

--------------------------------------------------------------------------------
-- Select Capture device
ret=ar1.SelectCaptureDevice(capture_device)
if(ret~=0)
then
    print("******* Wrong Capture device *******")
    return
end

-- RS232 Connect
ret=ar1.Connect(uart_com_port,baudrate,timeout)
if(ret~=0)
then
    print("******* Connect FAIL *******")
    return
end

-- Download BSS Firmware
ret=ar1.DownloadBSSFw(bss_path)
if(ret~=0)
then
    print("******* BSS Load FAIL *******")
    return
end

-- Download MSS Firmware
ret=ar1.DownloadMSSFw(mss_path)
if(ret~=0)
then
    print("******* MSS Load FAIL *******")
    return
end

-- SPI Connect
ar1.PowerOn(0, 1000, 0, 0)

-- RF Power UP
ar1.RfEnable()

------------------------- Other Device Configuration ---------------------------

-- Static Configuration Tab
ar1.ChanNAdcConfig(1, 0, 0, 1, 1, 1, 1, 2, 1, 0) 
ar1.LPModConfig(0, 0)
ar1.RfInit()

-- Data Configuration Tab
ar1.DataPathConfig(513, 1216644097, 0)
ar1.LvdsClkConfig(1, 1)
ar1.LVDSLaneConfig(0, 1, 1, 0, 0, 1, 0, 0)

-- Sensor Configuration Tab
ar1.ProfileConfig(0, 77, 7, 4.66, 56.9, 0, 0, 0, 0, 0, 0, 70.295, 0, 256, 5000, 0, 0, 30) -- yanik 2
ar1.ChirpConfig(0, 0, 0, 0, 0, 0, 0, 1, 0, 0)
ar1.DisableTestSource(0)
ar1.FrameConfig(0, 0, 1, 1, 50, 0, 0, 1)

-- SetUp DCA1000
ar1.GetCaptureCardDllVersion()
ar1.SelectCaptureDevice(capture_device)
ar1.CaptureCardConfig_EthInit("192.168.33.30", "192.168.33.180", "12:34:56:78:90:12", 4096, 4098)

print("******* mmStudio setup Complete! *******")