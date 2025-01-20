from pe_array import PEArray

# Test function
def test_pe_array():
    # Initialize input data, filter, and start ports
    start_port = [1]  # Signal starts at the top-left
    filter_port = [1, 2, 3]  # Simple filter values
    data_port = [1, 2, 3, 4, 5]  # Simple input values
    
    # Initialize the PE array with size 3x3
    pe_array = PEArray(n=3, start_port=start_port, filter_port=filter_port, data_port=data_port)
    
    # Function to print PEArray details in grid format
    def print_pe_array_details(pe_array, step):
        print(f"\nState after step {step}:")
        
        # Prepare 3x3 grids for data, filter, and result
        data_grid = []
        filter_grid = []
        result_grid = []
        for i in range(pe_array.n):
            row_data = []
            row_filter = []
            row_result = []
            for j in range(pe_array.n):
                pe = pe_array.grid[i][j]
                row_data.append(pe.in_data)
                row_filter.append(pe.in_filter)
                row_result.append(pe.result)
            data_grid.append(row_data)
            filter_grid.append(row_filter)
            result_grid.append(row_result)
        
        # Print Data Grid
        print("Data Grid:")
        for row in data_grid:
            print(" | ".join(map(str, row)))
        print("-" * 30)
        
        # Print Filter Grid
        print("Filter Grid:")
        for row in filter_grid:
            print(" | ".join(map(str, row)))
        print("-" * 30)
        
        # Print Result Grid
        print("Result Grid:")
        for row in result_grid:
            print(" | ".join(map(str, row)))
        print("-" * 30)

    # Print initial state
    print("Initial state:")
    print_pe_array_details(pe_array, "Initial")

    # Simulate multiple processing steps
    for step in range(5):  # Run for 5 steps
        pe_array.process()
        print_pe_array_details(pe_array, step + 1)

# Run the test
test_pe_array()