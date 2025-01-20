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


