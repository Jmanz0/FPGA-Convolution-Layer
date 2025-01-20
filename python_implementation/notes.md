I am creating one convolution layer in a dnn, i am converting a python script to verilog. The python file works properly but ignores dealing with bits. It is important to me that you convert this python script logic exactly as is and make a verilog code with it, my guidelines and python is below. Please ensure that the verilog code will wrong when implemented in Vivado and matches my python code logic.

What my implementation is for verilog:
Component Summary:
Address Generator: Goes through the data flow loop to generate the correct addresses for accessing input data, filters and also outputs.
Scheduler: Takes data from address generator and distributes it correctly to each PE array with the correct timing.
PE Cluster: Contains a cluster of 6 PE arrays, able to process one output row at a time
PE Array: Contains 3x3 array of PEs, able to process a 5x3 tile of input to produce a 3x3 tile of output
PE: Handles one portion of the row and filter, using a sliding window approach to multiply a 5 tile row for 3 outputs (per one row of filter).
Output address queue: Accumulates addresses for output aggregator.
Output aggregator/RELU: Brings together the outputs from the separate PE arrays and adds it to previous partial results. It also performs RELU on last output layer.
Write to RAM: Pipelines the output aggregator/RELU module, storing the final result in memory

Layer information:
Layer: Layer-3
Type: Conv
IFM Size: 16²
Input Channel: 32
OFM Size: 16²
Output Channel: 64
Kernel Size: 3×3
Stride: 1
Padding (zero): 1
ReLU: √
Q_IN: 5
Q_OUT: 5
Q_W: 8

1) Scheduler should be split into two modules, one that calculates the correct addresses for input_bram/out_address/filter_address and one for correctly distributing the data. Ideally I do not need to implement pipelines, and will have correct timing according to the clock cycles.

The second moduler is the data distributer, it takes in the addresses and makes sure it maps to the correct PEs/PE_arrays. (This is where i am setting the dataports, but in reality this would just be wires)

2) We should never have loops in verilog, this should only be generation loops.

3) We need to simulate this in vivado with actual BRAM, we do not want to make a mock one.

4) The output address is dircetly connected to aggregator module, in this we generate based on the overall loop and feed it in using a queue. So we wil need a seperate module for this.

5) We ignore relu for now

Data representation:
Data will be loaded into BRAM using a COE file. Input fmap data is stored as 5bit values, 16 values stored in a 128bit row (for easy retrieval). The kernel data is stored a 3 values per 32bit row; each value 8 bit in length. The last BRAM is 128bit addressing (output bram).

class Aggregator:
    def __init__(self, output_bram, pe_cluster):
        self.output_bram = output_bram
        self.pe_cluster = pe_cluster
        self.address_queue = []
        self.base_memory_addr = 0

        # State
        self.row_iteration = 0
        self.output_layer = 0
        self.input_layer = 0  # New stage added
        self.row = 0

        # Input
        # PE_Cluster finished
        
        # Output
        self.finished = 0
        self.output = [0] * 16
        self.output_address = 0
    
    def relu(self, data):
        for i in range(len(data)):
            data[i] = max(0, data[i])
        return data

    def process(self):
        self.finished = 0
        if self.pe_cluster[0].finished:
            current_address = self.address_queue.pop(0)
            self.output = self.output_bram.read(current_address, 128)

            # print([self.pe_cluster[i].output for i in range(len(self.pe_cluster))])
            # Process each PE cluster output
            for i in range(len(self.pe_cluster)):
                if self.pe_cluster[i].finished:
                    # Handle last PE cluster special case
                    if i == len(self.pe_cluster) - 1:  # Last PE cluster has 2 useless iterations
                        self.output[i*3] += self.pe_cluster[i].output[2]
                    else:
                        for j in range(3):
                            self.output[i*3 + j] += self.pe_cluster[i].output[j]

                    # if self.output_layer == 64:  # Apply ReLU at the final layer, this should be combined with the above loop, but for demonstration purposes, it is separated
                    #     self.output = self.relu(self.output)
                        
            # Write to BRAM by passing it off to aggregator
            self.finished = 1
            self.output_address = current_address

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

from pe import PE
class PEArray:
    """2D Array of Processing Elements"""
    def __init__(self, n, data_port, filter_port):
        self.n = n
        # Create an n x n grid of PEs
        self.grid = [[PE(3) for _ in range(n)] for _ in range(n)]
        
        self.finished = 0
        self.output = 0

        for i in range(n):
            for j in range(n):
                self.grid[j][i].in_data = data_port
                if i == 0:
                    self.grid[j][i].in_filter = filter_port
    
    def print_array_in_data(self):
        # Print the array
        for j in range(self.n):
            for i in range(self.n):
                print(self.grid[j][i].in_data, end=" ")
            print()
        print("---------------")
    
    def print_array_results(self):
        # Print the array
        for j in range(self.n):
            for i in range(self.n):
                print(self.grid[j][i].result, end=" ")
            print()
        print("---------------")
    
    def print_array_start(self):
        # Print the array
        for j in range(self.n):
            for i in range(self.n):
                print(self.grid[j][i].new_in_data, end=" ")
            print()
        print("---------------")
    
    def print_array_filter(self):
        # Print the array
        for j in range(self.n):
            for i in range(self.n):
                print(self.grid[j][i].filter, end=" ")
            print()
        print("---------------")

    # Simulates the systolic array movement
    def process(self):
        self.finished = 0
        # Iterate through the grid, updating values & starting the process
        for j in range(self.n):
            for i in range(self.n):
                self.grid[j][i].process_one()

        for j in range(self.n):
            for i in range(self.n):
                # Propogate filter rightwards
                if i != 0:
                    self.grid[j][i].in_filter = self.grid[j][i-1].filter.copy()
                
                # Propogate results downwards (only once done)
                if j != 0:
                    if self.grid[j-1][i].finished:
                        self.grid[j][i].in_result = self.grid[j-1][i].result.copy()

                # if i > 0 and j < self.n - 1:
                #     self.grid[j][i].in_data = self.grid[j+1][i-1].data.copy()
                #     self.grid[j][i].new_in_data[0] = self.grid[j+1][i-1].new_out_data[0]
                
                # Propogate start signal
                above_start = [1] if j != 0 and self.grid[j-1][i].out_start[0] else [0]
                left_start = [1] if i != 0 and self.grid[j][i-1].out_start[0] else [0]
                
                if i != 0 or j != 0:
                    self.grid[j][i].start[0] = 1 if (above_start[0] or left_start[0]) else 0

        
        for i in range(self.n):
            if self.grid[self.n-1][i].finished:
                self.output = self.grid[self.n-1][i].result
                self.finished = 1
                break


class PE:
    """Processing Element using Sliding Window"""
    def __init__(self, window_size=5):
        # OUT
        self.data = [0] * 5 # data register
        self.filter = [0] * window_size # filter window register
        self.result = [0] * 3 # output register
        self.finished = 0
        self.out_start = [0]

        # IN
        # Clock signal
        self.new_in_data = [0]
        self.in_data = [0,0,0,0,0] # !!! ASSUME THAT NO INPUT MEANS 0
        self.in_filter = [0,0,0]
        self.in_result = [0,0,0,0,0]
        self.start = [0]

    
        self.state = 0  # State machine: 0=IDLE, 1=Multiply, 2=Accumulate, 3=Reset
        self.sliding_window = [0] * window_size
        self.iteration = 0

    def process_one(self):
        """
        Perform the PE computation with sliding window.
        
        Args:
            in_data (int): Input value for the sliding window.
            in_filter (int): Input filter value for the sliding window.
            in_result (int): Accumulated value from the previous PE.
        """

        if self.start[0]: # multiply stage (PROPAGATE DATA DIAGNALLY)
            self.finished = 0
            self.state = 1
            
            if self.new_in_data[0]:
                self.data = self.in_data.copy()
                self.new_in_data[0] = 0
            
            self.sliding_window = self.data[:len(self.sliding_window)]
            self.filter = self.in_filter.copy()
            
            # Reset inputs
            self.start[0] = 0
            self.out_start[0] = 1
            # self.in_data = [0,0,0,0,0]
        
        if self.start[0] or self.state == 1:
            # perform 3 mac units)
            self.result[self.iteration] = sum(self.sliding_window[i] * self.filter[i] for i in range(3))
            self.iteration += 1
            # Reset signals, this would not be necessary in hardware
            if self.iteration == 2:
                self.out_start[0] = 0
            if self.iteration == 3:
                self.state = 2
                self.iteration = 0
            else:
                self.sliding_window = self.sliding_window[1:] + [self.data[self.iteration + 2]]

        elif self.state == 2:  # Accumulate stage
            self.result = [x + y for x, y in zip(self.in_result, self.result)]
            self.finished = 1
            self.state = 3
        
        elif self.state == 3:  # Idle/Reset stage
            self.finished = 0
            self.state = 0
        
from pe_array import PEArray
class Scheduler:
    def __init__(self, input_bram, filter_bram):
        self.input_bram = input_bram
        self.filter_bram = filter_bram
        self.aggregator = None
        self.write_ram = None
        # broadcast across left/bottom edges (56 bits)
        self.data_port1 = [0] * 8
        self.data_port2 = [0] * 8
        self.data_port3 = [0] * 8
        self.data_port4 = [0] * 8
        self.data_port5 = [0] * 8
        self.data_port6 = [0] * 8

        # broadcast across left edges (35 bits)
        self.filter_port = [0] * 5

        self.pe_cluster = [PEArray(3, self.data_port1, self.filter_port),
                            PEArray(3, self.data_port2, self.filter_port),
                            PEArray(3, self.data_port3, self.filter_port),
                            PEArray(3, self.data_port4, self.filter_port),
                            PEArray(3, self.data_port5, self.filter_port),
                            PEArray(3, self.data_port6, self.filter_port)]

    def process_step(self):
        for pe_array in self.pe_cluster:
            pe_array.process()
        self.aggregator.process()
        self.write_ram.process()


    def run(self):
        # FILTER (32)
        base_ifm_bram_addr = 0
        base_filter_bram_addr = 0


        num_layers = 32
        num_rows = 20 # Need to add padding vertically because PEs mess things up
        num_filters = 64

        for input_layer in range(num_layers):
            for skip_row in range(0, num_rows - 4, 3):
                # Simulates the new data propgatation. We would need to do this in hardware. For each new "skip_row" we need to update the stale data in the PEs. Within the next 5 clock cycles, we need are broadcasting the data where the PEs can grab it when they need (i.e. when they have a start signal)
                for pe_array in self.pe_cluster:
                    for i in range(3):
                        for j in range(3):
                            pe_array.grid[j][i].new_in_data[0] = 1
                            if i == 2 and j == 2:
                                pe_array.grid[j][i].new_in_data[0] = 0
                new = 1
                                    
                for out_f in range(num_filters):
                    for pe_array in self.pe_cluster:
                        pe_array.grid[0][0].start[0] = 1
                            
                    for count, row in enumerate(range(skip_row, skip_row + 5)): # we accumulate 3 rows at a time
                        # Distribute the data to each PE
                        if out_f == 0:
                            if row == 0 or row >= 17:
                                ifs_row = [0.0] * 18
                            else:
                                read_address = base_ifm_bram_addr + input_layer * 16 + row - 1
                                ifs_row = [0.0] + self.input_bram.read(read_address, 128) + [0.0]
                            self.data_port1[:] = ifs_row[:5]
                            self.data_port2[:] = ifs_row[3:8]
                            self.data_port3[:] = ifs_row[6:11]
                            self.data_port4[:] = ifs_row[9:14]
                            self.data_port5[:] = ifs_row[12:17]
                            self.data_port6[:] = ifs_row[13:18]
                        # For the 1 extra cycle of MAC operations
                        # self.pe_cluster[0].print_array()
                        
                        if count < 3:
                            filter_address = base_filter_bram_addr + out_f * 32 * 3 + input_layer * 3 + count
                            self.filter_port[:] = self.filter_bram.read(filter_address, 32)
                        if count < 4:
                            self.process_step()
                        if 1 <= count < 4:
                            out_address = base_ifm_bram_addr + out_f * 16 + row - 1
                            self.aggregator.address_queue.append(out_address)
                            
                        # This is to ensure that the new_in_data is set to 1 during the correct cycle. In hardware the new data is broadcasted to all PEs in the same cycle, and PE's select what they need
                        if new:
                            new = 0
                            for pe_array in self.pe_cluster:
                                pe_array.grid[2][2].new_in_data[0] = 1
                        
        for i in range(100): # need some extra steps here
            self.process_step()

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

# Writes aggregated values to BRAM
class WriteRam:
    def __init__(self, output_bram, pe_cluster, aggregator):
        self.output_bram = output_bram
        self.pe_cluster = pe_cluster
        self.aggregator = aggregator

        # Inputs
        # self.finished = 0
        # self.output = [0] * 16
        # self.address = 0

        # Outputs
        self.finished = 0
    
    def process(self):
        finished = self.aggregator.finished
        output = self.aggregator.output.copy()
        address = self.aggregator.output_address

        self.finished = 0

        if finished:
            self.output_bram.write(address, output, 128)
            self.finished = 1

