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

