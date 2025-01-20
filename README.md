**Results:**  
**Total utilization:** 82.06%  
Total MACS: 14058616   
Total Active MACS: 11535975  
Total Active PE Array MACS: 13271040 \* .81 \= 10749543  
Actual MAC usage: 81% of the PE array

**Analysis**: As the 6th PE array only is ⅓ efficient we waste quite a few macs. For improvements we would need to be able to use partial PE arrays, employing a more flexible scheduling algorithm.  

**Architecture:**  
This implementation is of the 2nd convolution (the 3rd layer)  
<img width="1054" alt="Screenshot 2025-01-19 at 10 07 45 PM" src="https://github.com/user-attachments/assets/f13b3ff5-fe7c-416a-af0e-3f4b4244a11c" />


**Component Summary:**

* **Address Generator:** Goes through the data flow loop to generate the correct addresses for accessing input data, filters and also outputs.  
* **Scheduler:** Takes data from address generator and distributes it correctly to each PE array with the correct timing.  
* **PE Cluster:** Contains a cluster of 6 PE arrays, able to process one output row at a time  
* **PE Array:** Contains 3x3 array of PEs, able to process a 5x3 tile of input to produce a 3x3 tile of output  
* **PE:** Handles one portion of the row and filter, using a sliding window approach to multiply a 5 tile row for 3 outputs (per one row of filter).  
* **Output address queue:** Accumulates addresses for output aggregator.  
* **Output aggregator/RELU:** Brings together the outputs from the separate PE arrays and adds it to previous partial results. It also performs RELU on last output layer.  
* **Write to RAM:** Pipelines the output aggregator/RELU module, storing the final result in memory

This architecture is based on Eyeriss V1; an energy efficient CNN focused on data reuse. We utilize the same row stationary format.

We have a total number of 286 MACS. Within each of the 6 PE arrays, a single PE contains 5 MACS, resulting in 270 MACS across the PE arrays; the output aggregator must also read memory and aggregate stored results with just computed results (part of the accumulate cycle), resulting in an extra 16 macs. We utilize tiling (5x5) to efficiently support reuse at the PE Array level.

**Data flow (for-loop manner)**

FOR each input\_channel from 0 to C-1:  
    FOR each tile\_height from 0 to input\_height, skip 3 rows at a time:  
         // Process 3 rows at a time  
        FOR each output\_channel from 0 to F-1:  
                FOR each 3 output pixels (width) from 0 to tile\_width:  
                    // Split the row into 6 portions, processing 3 output pixels per PE array  
                    psum \= 0  \# Initialize partial sum  
                    FOR each filter\_row from 0 to K-1:  
                        sliding\_window \= \[\]  \# Initialize sliding window  
                        FOR each filter\_width from 0 to K-1:  
                                \# Extract patch into sliding window  
                                sliding\_window.append(  
                                    IFM\[fmout\_height \+ filter\_row\]\[fmout\_widthx\]\[input\_channel\]  
                                )  
                        \# Perform matrix multiplication with filter  
                        psum \+= matrix\_multiply(  
                            sliding\_window, Filter\[filter\_row\]\[filter\_width\]\[output\_channel\]  
                        )  
                    OFM\[fmout\_height\]\[fmout\_width\]\[output\_channel\] \= psum

**Visual representation:**  
**<img width="942" alt="Screenshot 2025-01-19 at 9 51 45 PM" src="https://github.com/user-attachments/assets/a1e3a489-9013-49d3-a5d7-88688c64be21" />**

1) Within our dataflow, we are processing 3 rows at a time. For a given held constant input, we apply each of the kernels to get a partial result for the 3 rows  
2) This continues on for all rows to get a partial result for all rows.  
3) Finally we move on to the next layer, fetching the previous result from BRAM and adding onto it.

**Data flow at the Cluster level:**  
<img width="936" alt="Screenshot 2025-01-19 at 9 51 52 PM" src="https://github.com/user-attachments/assets/8be27508-d9b5-4685-a941-c6aa0ae7195a" />  
**\*** *Split each row into 5 row tiles, splitting across our 6 PE clusters*  
<img width="944" alt="Screenshot 2025-01-19 at 9 51 58 PM" src="https://github.com/user-attachments/assets/88980aa5-1b41-4dc2-b730-33bd97e0e007" />
**\*** *Once a PE array finished processing a row, it gets aggregated in output aggregator. This aggregator fetches any partial results from BRAM for this output layer and adds it.<img width="937" alt="Screenshot 2025-01-19 at 9 52 02 PM" src="https://github.com/user-attachments/assets/7f4e228a-24e8-4b7f-bc07-d50679575a4e" />

**Finally we store these results in memory*  
**Data flow at the PE level:**  
<img width="842" alt="Screenshot 2025-01-19 at 9 52 12 PM" src="https://github.com/user-attachments/assets/324af662-1c0f-4580-a1ac-e71cc2079a7e" />
\* *From the 5 input integers, we produce 3 output results using a sliding window approach*

A whole cycle of the row data results in 4 clock cycles, 3 for multiplying and 1 for aggregation between PEs.

**Data flow at the PE Array layer:**  
<img width="912" alt="Screenshot 2025-01-19 at 9 52 19 PM" src="https://github.com/user-attachments/assets/bd107cd7-8d36-42ac-a7f2-e4b37236e7ab" />

**Filters**: Propagated column by column across the PE, one clock cycles at a time.  
**Partial results**: Propagated row by row across the PE, one clock cycle at a time after finished processing multiplication.  
**Data**: Is broadcasted across the PE, each sharing data diagonally.

**Filter Channels:** Each PE array have filters broadcasted across the left column, where the PE takes the values when needed:  
<img width="512" alt="Screenshot 2025-01-19 at 9 52 24 PM" src="https://github.com/user-attachments/assets/1b36a0a8-9977-41b6-81c0-0fca1c29aa3a" />

**Data Channels:** Data is broadcasted across all PEs within a cluster, the PE takes the values on need basis.  
<img width="602" alt="Screenshot 2025-01-19 at 9 52 27 PM" src="https://github.com/user-attachments/assets/d99ae59a-574a-4a7b-803b-fba6463a92c5" />


**Output Channel:** Results are multiplexed from the bottom PE of each column, once done processing.   
<img width="517" alt="Screenshot 2025-01-19 at 9 52 31 PM" src="https://github.com/user-attachments/assets/d3f5650a-7ac3-4cab-b17f-5e3fbc830627" />


**Visual Example of Data Flow**   
1\) First row of the filter is propagated along the filter channel with the broadcast of the first row of the input data.   
<img width="639" alt="Screenshot 2025-01-19 at 9 52 35 PM" src="https://github.com/user-attachments/assets/4464c2ab-b165-4eae-8460-9ceb4f579607" />

2\) Second row of the filter is propagated along the filter channel with the broadcast of the second row of input data. Filter from column one, row one is propagated horizontally.  
<img width="593" alt="Screenshot 2025-01-19 at 9 52 39 PM" src="https://github.com/user-attachments/assets/12d62161-58bb-4751-aebc-9eccce5eb376" />

3\) On the fourth cycle, the first PE is finished multiplying and accumulates the previous result (None) and propagates it to the below PE.  
<img width="598" alt="Screenshot 2025-01-19 at 9 52 44 PM" src="https://github.com/user-attachments/assets/e80375ee-89e0-4e5d-bbdc-9fe1ec5f61e4" />

4\) On the fifth cycle, all columns have started on the first filter. The first PE now is pipelined to start on the second output layer, holding its input data constant. Although this PE now receives a new filter for the new output layer.  
<img width="619" alt="Screenshot 2025-01-19 at 9 52 47 PM" src="https://github.com/user-attachments/assets/edd0e65c-52f1-4516-be16-39ab9d6410c6" />


**Storage Structure for efficient scheduling:**  
*Input map (stored sequentially in memory in row-major format):*  
	*Input1 **Fmap:*** flattened \[row0, row1, row2…\]  
	*Input2 **Fmap:*** flattened \[row0, row1, row2…\]...  
\-128-bit Addressing

*Weight Structure:*  
	*1st **Kernel:*** flattened \[row0, row1, row2…\]  
	*2nd **Kernel:*** flattened \[row0, row1, row2…\]  
	*3rd **Kernel:*** flattened \[row0, row1, row2…\]  
\-32-bit Addressing

*Output structure (re-used):*  
	*Same as input map*   
*\* Cannot reuse input map area as data fetching may still happen during writing output*  
**\-**128-bit Addressing

<img width="939" alt="Screenshot 2025-01-19 at 9 52 52 PM" src="https://github.com/user-attachments/assets/4fe9cbe9-94a3-478f-8bed-68402d2733c5" />
