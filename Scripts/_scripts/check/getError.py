import os
from math import sin, cos, radians

try:
    import matplotlib.pyplot as plt
except:
    print("Matplot lib isn\'t installed - cannot plot")
    from unittest.mock import MagicMock
    plt = MagicMock()

# Test data, U,W is not phi/U0
Mm = dict()   #[Position][Y U W]
Yu = dict()   #[Position][Y U]
Yekp = dict() #[position][Y epsilon k p]

cs = {'-25' : [0,  1.3e-1],
      '025' : [10, 1.34341204e-01],
      '060' : [10, 1.40418891e-01],
      '100' : [10, 1.47364818e-01],
      '175' : [10, 1.60388431e-01],
      '250' : [10, 1.73412044e-01],
      '330' : [10, 1.87303899e-01],
      '405' : [10, 2.00327512e-01]}

def getExperimentalData():
    for filename in os.listdir('test60'):
        if 'Mm' in filename and '.dat' in filename:
            position = filename[2:5]
            print('Parsing:', filename, 'which has info for location', position, 'mm')
            file_name = os.path.join('test60', filename)
            file = open(file_name)
            text = file.read().split('\n')
            file.close()
            
            Mm[position] = list()

            for line_no in range(10, len(text)):
                line = text[line_no]
                line = line.split(' ')
                out_line = list()
                
                for item in line:
                    if 0 < len(item):
                        out_line.append(float(item))
                        
                if len(out_line) == 3:
                    Mm[position].append(out_line)

def getCFDData():
    # Get latest folder from CFD output
    latest_folder = 0
    for folder in os.listdir('sets'):
        if latest_folder < int(folder):
            latest_folder = int(folder)
            print('Latest folder from CFD is for iteration', latest_folder)

    # Parse CFD output files
    for filename in os.listdir(os.path.join('sets', str(latest_folder))):
        position = filename[4:7]
        print('Parsing:', filename, 'which has info for location', position, 'mm')
        file = open(os.path.join('sets', str(latest_folder), filename))
        text = file.read().split('\n')
        file.close();

        if 'epsilon' in filename:
            destination = Yekp  # works as a pointer!
        else:
            destination = Yu;

        destination[position] = list()
        
        for line in text:
            this_line = line.split("\t")

            out_line = list()
            for item in this_line:
                try:
                    value = float(item)
                    out_line.append(value)
                except:
                    pass
            try:
                out_line[0] = out_line[0]*1000 #convert Y to meters
            except:
                next
            destination[position].append(out_line)
    print()
            

def calc_y(position, y):
    #($2-$$1)*1000/cos(angle)
    radius = cs[position][1]
    angle  = radians(cs[position][0])
    y_actual = (radius - y/1000)/cos(angle) * 1000
    return y_actual

def interpolate_U(position, Y_lower, Y_upper, Y_actual, Y_lower_index, Y_upper_index):
    deviation_percent = (Y_actual - Y_lower) / (Y_upper - Y_lower)
    data_lower = Yu[position][Y_lower_index]
    data_upper = Yu[position][Y_upper_index]

    data_range = list([1]*len(data_upper))
    data_interpolated = list([1]*len(data_upper))

    for i in range(0, len(data_upper)):
        data_range[i] = data_upper[i] - data_lower[i]
        data_interpolated[i] = data_lower[i] + deviation_percent * data_range[i]

    return data_interpolated

def subtract(array1, array2):
    new_array = list()
    for i in range(0, min(len(array1), len(array2))):
        new_array.append(array1[i] - array2[i])

    return new_array

def getScoreUW (plotComparison=[]):
    score = 0
    num_tests = 0
    
    for position in Mm:
        # We can plot a comparison if desired,
        #  just give a position you want the plot to be
        #  made
        if position in plotComparison:
            comparison_Y = list()
            comparison_Uexp = list()
            comparison_Wexp = list()
            comparison_Ucfd = list()
            comparison_Wcfd = list()

        # For each position, and for each point in the experimental data
        for data_exp in Mm[position]:        
            Y_exp = data_exp[0]
            U_exp = data_exp[1]
            W_exp = data_exp[2]

            # Search through the CFD data using upper and lower bounds
            #  for the corrosponding experimental Y value. As we search
            #  upwards we break as soon as we get a Y value above the
            #  experimental Y value
            for index_Yu in range(0, len(Yu[position])-1):
                data_cfd = Yu[position][index_Yu]
                Y_cfd = calc_y(position, data_cfd[0])
                if Y_exp <= Y_cfd:
                    Y_upper = Y_cfd
                    Y_upper_index = index_Yu
                    break
                else:
                    Y_lower = Y_cfd
                    Y_lower_index = index_Yu

            
            # Then we interpolate between the upper and lower bounds
            if Y_upper < Y_lower:    # Unless something went wrong
                continue
            elif Y_upper != Y_lower: # And given Upper is not equal to lower
                Y_cfd = interpolate_U(position,
                                      Y_lower, Y_upper, Y_exp,
                                      Y_lower_index, Y_upper_index)
            else:                    # otherwise if we have an exact number, use that
                Y_cfd = Yu[position][Y_upper_index]

            # Now we can calculate the U and W values            
            angle = radians(cs[position][0])

            # Calculate the U value
            U_cfd = Y_cfd[3] * cos(angle) + Y_cfd[2] * sin(angle)
            U_error = (U_cfd-U_exp) / U_exp

            # Calculate the W value
            W_cfd = -Y_cfd[1]
            W_error = (W_cfd - W_exp)/W_exp

            if 0.5 < max(abs(U_error), abs(W_error)):
                print('At', position, 'between', round(Y_lower,2),
                      '<' , round(Y_exp,2), '<', round(Y_upper,2))
            
                if 0.5 < abs(U_error):
                    print('U is about', round(U_error*100,2), '% off the actual value')
                    print('U:', round(U_cfd/11.6,4), '!=', round(U_exp/11.6,4), '\n')
                    
                if 0.5 < abs(W_error):
                    print('W is about', round(W_error*100,2), '% off the actual value')
                    print('W:', round(W_cfd/11.6,4), '!=', round(W_exp/11.6,4), '\n')
                
            if position in plotComparison:
                comparison_Ucfd.append(U_cfd)
                comparison_Wcfd.append(W_cfd)
                comparison_Uexp.append(U_exp)
                comparison_Wexp.append(W_exp)
                comparison_Y.append(Y_exp)
                

            score = score + (1 - abs(U_error)) + (1 - abs(W_error))
            num_tests = num_tests + 2 #Max score


        if position in plotComparison:
            plt.plot(comparison_Y, subtract(comparison_Ucfd, comparison_Uexp), 'b--',
                     comparison_Y, subtract(comparison_Wcfd, comparison_Wexp), 'b--',
                     comparison_Y, comparison_Ucfd, 'r-',
                     comparison_Y, comparison_Uexp, 'g^',
                     comparison_Y, comparison_Wcfd, 'r-',
                     comparison_Y, comparison_Wexp, 'g^')
            plt.show()
            
    return score, num_tests

if __name__ == '__main__':
    getExperimentalData()
    getCFDData()
    score, max_score = getScoreUW(['405'])
    print(round(score/max_score,4)*100, '%')

        
        
