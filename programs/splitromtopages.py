#page means chunk of data with the size of 64 bytes

def PageOfRom(romData, page):
    pageContent = bytearray([0x00] * 64)
    
    for i in range(0, 64, 16):
        print("{:04x}".format((page*64) + i), end=': ')
        for j in range(16):
            pageContent[i + j] = romData[(page*64) + (i + j)]
            print("{:02x}".format(pageContent[i + j]), end=' ')
        print('')
    
    return pageContent

def loadRom(filename):
    with open(filename, "rb") as rom:
        romData = rom.read()
        return romData

