class BRAM:
    def __init__(self, size):
        self.size = size
        self.mem = [0] * size

    def get_physical_address(self, addr, access_width):
        """
        Convert a logical address to a physical address based on access width.
        """
        if access_width == 128:
            return addr * 16
        elif access_width == 32:
            return addr * 4
        else:
            raise ValueError("Unsupported access width. Use 32 or 128.")

    def read(self, addr, access_width):
        """
        Read data from the logical address, scaled by the access width.
        """
        physical_addr = self.get_physical_address(addr, access_width)
        if access_width == 128:
            return self.mem[physical_addr : physical_addr + 16].copy()  # Read 16 bytes ()
        elif access_width == 32:
            return self.mem[physical_addr:physical_addr + 3].copy()  # Read 4 bytes

    def write(self, addr, data, access_width):
        """
        Write data to the logical address, scaled by the access width.
        """
        physical_addr = self.get_physical_address(addr, access_width)
        if access_width == 128:
            if len(data) != 16:
                raise ValueError("Data size must be 16 bytes for 128-bit writes.")
            for i in range(16):
                self.mem[physical_addr + i] = data[i]
        elif access_width == 32:
            for i in range(4):
                self.mem[physical_addr + i] = data[i]