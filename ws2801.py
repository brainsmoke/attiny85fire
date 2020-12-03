#!/usr/bin/env python3
#
# Copyright (c) 2020 Erik Bosman <erik@minemu.org>
#
# Permission  is  hereby  granted,  free  of  charge,  to  any  person
# obtaining  a copy  of  this  software  and  associated documentation
# files (the "Software"),  to deal in the Software without restriction,
# including  without  limitation  the  rights  to  use,  copy,  modify,
# merge, publish, distribute, sublicense, and/or sell copies of the
# Software,  and to permit persons to whom the Software is furnished to
# do so, subject to the following conditions:
#
# The  above  copyright  notice  and this  permission  notice  shall be
# included  in  all  copies  or  substantial portions  of the Software.
#
# THE SOFTWARE  IS  PROVIDED  "AS IS", WITHOUT WARRANTY  OF ANY KIND,
# EXPRESS OR IMPLIED,  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY,  FITNESS  FOR  A  PARTICULAR  PURPOSE  AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM,  DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT,  TORT OR OTHERWISE,  ARISING FROM, OUT OF OR IN
# CONNECTION  WITH THE SOFTWARE  OR THE USE  OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# (http://opensource.org/licenses/mit-license.html)
#

import sys
import intelhex, avr

CLKPIN=4
DATAPIN=3

def frame_timing(frame, idle_cycles, frame_cycles):
    print()
    print('cycles/frame+pause: {:d}, idle time: {:d}'.format(frame_cycles, idle_cycles))

def byte_hex(byte):
    print ('{:02x} '.format(byte), end='')

def frame_stdout(frame, idle_cycles, frame_cycles):
    sys.stdout.buffer.write(bytes(frame))
    sys.stdout.flush()

def print_cells(ctx):
    for y in range(20):
        for x in range(24):
            v = ctx['mem'][0x60+y*24+x]
            print(f"{v:4d}", end='')
        print()

def wave_func(datapin, clkpin, byte_func=None, frame_func=None):
    last=-1
    last_up=-1
    last_frame=-1
    byte=0
    bits=0
    frame = []

    def func(ctx, addr, old, new):
        nonlocal last, last_up, last_frame, bits, byte, frame
        if ctx['ts']-last > 10:
            assert( old == 0 )
        last=ctx['ts']
        old = old & ( (1<<datapin) | (1<<clkpin) )
        new = new & ( (1<<datapin) | (1<<clkpin) )
        if old != new:
            if new & (1<<clkpin):
                assert ( new == old | (1<<clkpin) )

        if old != new and new == old|(1<<clkpin):
            ts=ctx['ts']
            d = ts-last_up
            data = bool( new & (1<<datapin) )
            if d > 100:
#                print_cells(ctx)
                frame_func(frame, ts-last_up, ts-last_frame)
                frame = []
                last_frame = ts

            last_up=ts

            byte = byte<<1 | int( data )
            bits += 1
            if bits == 8:
                if byte_func:
                    byte_func(byte)
                frame.append(byte)
                byte = 0
                bits = 0

    return func

if __name__ == '__main__':

    if sys.argv[1] == '-out':
        func = wave_func(DATAPIN,CLKPIN, None, frame_stdout)
    elif sys.argv[1] == '-timing':
        func = wave_func(DATAPIN,CLKPIN, byte_hex, frame_timing)
    else:
        print ("Usage: {} -out|-timing < hexfile".format(sys.argv[0]), file=sys.stderr)
        sys.exit(1)

    flash = intelhex.parse(open(sys.argv[2], 'r').read())

    ctx = avr.init_ctx(flash)
    avr.watch_io(ctx, avr.PORTB, func)

    avr.run(ctx)
