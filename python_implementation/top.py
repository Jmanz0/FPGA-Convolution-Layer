import math
from bram import BRAM
from scheduler import Scheduler
from aggregator import Aggregator
from write_to_ram import WriteRam

class Top:
    def __init__(self):
        # Separate BRAMs for input, filters, and output
        self.input_bram = BRAM(16 * 16 * 32 * 8 * 100)  # BRAM for input FMAP
        self.filter_bram = BRAM(18432 * 8)  # BRAM for filters
        self.output_bram = BRAM(18432 * 8)  # BRAM for output FMAP

        self.scheduler = Scheduler(self.input_bram, self.filter_bram)
        self.aggregator = Aggregator(self.output_bram, self.scheduler.pe_cluster)
        self.write_ram = WriteRam(self.output_bram, self.scheduler.pe_cluster, self.aggregator)
        self.scheduler.aggregator = self.aggregator
        self.scheduler.write_ram = self.write_ram

    def load_bram(self, file_path, bram, row_length, access_width=128, padding=0):
        """
        Loads data into BRAM from a file containing row-major format values (one value per line).
        """
        addr = 0
        padded_row_size = row_length + padding  # Total size including padding

        with open(file_path, "r") as f:
            data = [float(line.strip()) for line in f.readlines()]  # Read and parse all values

        offset = 0
        total_elements = len(data)

        while offset < total_elements:
            # Extract one row of data
            row_data = data[offset: offset + row_length]

            # Add padding if the row is incomplete
            if len(row_data) < row_length:
                row_data += [0.0] * (row_length - len(row_data))
            row_data += [0.0] * padding  # Ensure padding is added

            # Write row to BRAM
            if access_width == 128:  # Write in 128-bit chunks
                bram.write(addr, row_data, 128)
            elif access_width == 32:  # Write in 32-bit chunks
                bram.write(addr, row_data, 32)

            # Move to the next row
            offset += row_length
            addr += 1

    def store_bram_to_file(self, bram, out_file, total_elements):
        """
        Reads data from BRAM memory address by address and writes each value to a file, one value per line.
        """
        with open(out_file, "w") as f:  # Open file in text mode
            for addr in range(total_elements):
                value = bram.mem[addr]  # Read directly from memory
                f.write(f"{value}\n")  # Write each value on a new line

    def initialize(self):
        # Load data into the respective BRAMs
        self.load_bram(
            "conv2.input.real.dat", 
            self.input_bram, 
            row_length=16,  # 16 elements per row for input FMAP
            access_width=128, 
            padding=0,  # No padding needed
        )

        self.load_bram(
            "conv2.real.dat", 
            self.filter_bram, 
            row_length=3,  # 3 elements per row for filters
            access_width=32, 
            padding=1,  # Align to 32-bit boundary
        )

    def run(self):
        # Run scheduler and aggregator
        self.scheduler.run()

        # Save output data from output BRAM
        self.store_bram_to_file(
            self.output_bram, 
            "output.dat", 
            total_elements=16384,  # 18432 elements in output FMAP
        )

def main():
    top = Top()
    top.initialize()
    top.run()

if __name__ == "__main__":
    main()