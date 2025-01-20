# !!! NO RELU RIGHT NOW
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