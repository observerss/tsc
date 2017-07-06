# TSC(Time Series Compressor)

A compressor that specialize in compressing and decompressing time series data

Input can be pure number csv with headers, numpy array or pandas dataframe

It performs well only on all sized data, but will take too much time on files larger than 10M. You'd better split big file into small ones

## Usage

```py3
import tsc
m = tsc.compress('a,b,c\n1,2,3\n1,2,4\n')
tsc.decompress(m)
```

## Speed

Speed test suggests that, compared to `brotli`, which is the best text compressor as long as I known, it will be around 40-60% faster in compressing time and the result will be 10%-30% smaller, based on stock tick and depth data.


## Implementation

Time series data often have similar values across time, so in `tsc`, we calculate the delta values, then calculate entropies and possible replaces, finally we feed data to `brotli` which takes care of the rest.
