#!/usr/bin/env python
import argparse
import zlib

arg_parser = argparse.ArgumentParser()
arg_parser.add_argument('data')
args = arg_parser.parse_args()

input = bytes.fromhex(args.data if not args.data.startswith('0x') else args.data[2:])
zipped = zlib.compress(input)[2:-4]
print('0x' + ''.join(x.hex() for x in (
    int(32).to_bytes(32),
    int(len(zipped)).to_bytes(32),
    zipped
)))