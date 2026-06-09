import splitromtopages as r

def writeOverAllMemory(ser, pageCount):
    romData = r.loadRom("a.out")
    
    for i in range(pageCount):
        pageArray = r.PageOfRom(romData, i)
        print(ser.name)
        ser.write(pageArray)
        print((ser.read_until(b'MESSAGE END').decode("utf-8")))
