from pe import PE

# Test1
pe = PE(3)

data = [1, 2, 3, 4, 5]
filter = [1, 2, 3]

pe.in_data = data
pe.in_filter = filter
pe.in_result = [0, 0, 0]
pe.start = [1]
pe.new_in_data = [1]

for i in range(4):
    pe.process_one()

print(pe.finished, 1)
print(pe.result, [14, 20, 26])
print(pe.data, data)
print(pe.filter, filter)
print(pe.start[0], 0)
print(pe.new_in_data[0], 0)

# Test2
# pe = PE(3)

data = [0, 1, 2, 3, 4]
filter = [4, 3, 2]

pe.in_data = data
pe.in_filter = filter
pe.in_result = [0, 0, 0]
pe.start = [1]
pe.new_in_data = [1]

for i in range(4):
    pe.process_one()

print(pe.finished, 1)
print(pe.result, [7, 16, 25])
print(pe.data, data)
print(pe.filter, filter)
print(pe.start[0], 0)
print(pe.new_in_data[0], 0)



