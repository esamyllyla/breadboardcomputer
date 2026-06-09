with open("rom.bin", "rb") as rom:
    content = rom.read()
    for i in range(0, 32768, 16):
        print("{:04x}".format(i), end = ': ')
        for j in range(16):
            print("{:02x}".format(content[i + j]), end=' ')
        print("")
