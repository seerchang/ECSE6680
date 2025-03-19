function y_out_int = fir_filter_32bit(x_in_int, b_int)
    % FIR filter in 32-bit arithmetic with saturation.
    % x_in_int and b_int are 32-bit integer arrays (Q31).
    % y_out_int is the 32-bit output in Q31.
    %
    % Let:
    %   N  = number of filter taps
    %   Nx = length(x_in_int)
    %

    N  = length(b_int);
    Nx = length(x_in_int);

    y_out_int = zeros(1, Nx, 'int32');

    x_buffer = zeros(1, N, 'int32');

    for n = 1:Nx
        % shift buffer
        x_buffer = [x_in_int(n), x_buffer(1:end-1)];

        % 64-bit accumulator
        acc_64 = int64(0);

        for k = 1:N
            % Multiply in 64 bits
            prod_64 = int64(x_buffer(k)) * int64(b_int(k));
            
            % prod_64 = floor(prod_64 / 2^31);
            % disp(prod_64)
            prod_64 = bitsra(prod_64, 31); 
            
            % Accumulate in 64 bits
            acc_64 = acc_64 + prod_64;
        end

        % Q31 * Q31 => Q62 in the sum.
        % return to Q31. So we shift right by 31 bits.
        % acc_64 = bitsra(acc_64, 31);


        % saturate to 32-bit range
        if acc_64 >  2^31-1
            acc_64 =  2^31-1;  % saturate max
        elseif acc_64 < -2^31
            acc_64 = -2^31;    % saturate min
        end

        % cast back to int32
        y_out_int(n) = int32(acc_64);
    end
end