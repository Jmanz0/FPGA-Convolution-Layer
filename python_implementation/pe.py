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
        
    
# Idle: 
#    Wait for data?
# Data/Start: 0 Cycle (conceptually we do this in accumulate)
#    Receive data (which is a pointer to start)
# Accumulate: 3 Cycles
#    Multiply and accumulate (sliding window)
# Acucumplate upwaard e: 1 Cycle
#    Send data to the next PE, receive data from the previous PE & accumulate
