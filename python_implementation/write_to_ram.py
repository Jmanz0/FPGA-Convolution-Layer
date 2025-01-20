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