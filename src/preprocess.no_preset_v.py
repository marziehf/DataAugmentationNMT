# -*- coding: utf-8 -*-
import argparse, json, os
import numpy as np
import h5py
import codecs
#import torchfile
import re
import operator

parser = argparse.ArgumentParser()
parser.add_argument('--train_txt', default='train.txt')
parser.add_argument('--val_txt', default='valid.txt')
parser.add_argument('--test_txt', default='test.txt')
parser.add_argument('--output_h5', default='data.h5')
parser.add_argument('--output_json', default='data.json')
parser.add_argument('--quiet', action='store_true')
parser.add_argument('--encoding', default='utf-8')
parser.add_argument('--vocabsize', default='30000')
args = parser.parse_args()


if __name__ == '__main__':
  if args.encoding == 'bytes': args.encoding = None

  freq = {}
  with codecs.open(args.train_txt, 'r', args.encoding) as f:
       for line in f:
         for word in line.split():
             if word not in freq:
		freq[word] = 1
	     else:
		freq[word] += 1
  top_list = {}
  counterr = 0
  for w in sorted(freq, key=freq.get, reverse=True): 
     if counterr < int(args.vocabsize):
        top_list[w] = freq[w]
#        print w, freq[w]
#	print counterr
     counterr += 1
#     print counterr
#  print top_list
  token_to_idx = {}
  total_size = 0
  with codecs.open(args.train_txt, 'r', args.encoding) as f:
       for line in f:
         for word in line.split(): 
            total_size += 1
   #   for char in line:
            if word not in token_to_idx:
	#       print args.vocabsize, freq[word], word
	       if word in top_list:
		   #print word, freq[word]
	           token_to_idx[word] = len(token_to_idx) + 1

  token_to_idx['unk'] = len(token_to_idx) + 1
  # Choose the datatype based on the vocabulary size
  dtype = np.uint8
  if len(token_to_idx) > 255:
    dtype = np.uint32
  if not args.quiet:
    print 'Using dtype ', dtype

 
  train_size = 0
  with codecs.open(args.train_txt, 'r', args.encoding) as f:
    for line in f:
      for char in line.split():
#        if char in token_to_idx:
         train_size += 1
  val_size = 0
  with codecs.open(args.val_txt, 'r', args.encoding) as f:
    for line in f:
      for char in line.split():
       # if char in token_to_idx:
         val_size += 1
  test_size = 0
  with codecs.open(args.test_txt, 'r', args.encoding) as f:
    for line in f:
      for char in line.split():
        #if char in token_to_idx:
        test_size += 1

  train = np.zeros(train_size, dtype=dtype)
  val = np.zeros(val_size, dtype=dtype)
  test = np.zeros(test_size, dtype=dtype)
  splits = [train, val, test]

  # Go through the file again and write data to numpy arrays
  cur_idx = 0
  with codecs.open(args.train_txt, 'r', args.encoding) as f:
    for line in f:
      for char in line.split():
	if char in token_to_idx:
           splits[0][cur_idx] = token_to_idx[char]
           cur_idx += 1
	   train_size += 1
  cur_idx = 0
  with codecs.open(args.val_txt, 'r', args.encoding) as f:
    for line in f:
      for char in line.split():
        if char in token_to_idx:
           splits[1][cur_idx] = token_to_idx[char]
           cur_idx += 1
	else:
#	   print token_to_idx['unk']	   
	   splits[1][cur_idx] = token_to_idx['unk']
	   cur_idx += 1
  cur_idx = 0
  with codecs.open(args.test_txt, 'r', args.encoding) as f:
    for line in f:
      for char in line.split():
        if char in token_to_idx:
           splits[2][cur_idx] = token_to_idx[char]
           cur_idx += 1
	else:
	   splits[2][cur_idx] = token_to_idx['unk']
           cur_idx += 1
      
  if not args.quiet:
    print 'Total vocabulary size: %d' % len(token_to_idx)
    print '  Training size: %d' % train_size
    print '  Val size: %d' % val_size
    print '  Test size: %d' % test_size
  
# Write data to HDF5 file
  with h5py.File(args.output_h5, 'w') as f:
    f.create_dataset('train', data=train)
    f.create_dataset('val', data=val)
    f.create_dataset('test', data=test)

  # For 'bytes' encoding, replace non-ascii characters so the json dump
  # doesn't crash
  if args.encoding is None:
    new_token_to_idx = {}
    for token, idx in token_to_idx.iteritems():
      if ord(token) > 127:
        new_token_to_idx['[%d]' % ord(token)] = idx
      else:
        new_token_to_idx[token] = idx
    token_to_idx = new_token_to_idx

  # Dump a JSON file for the vocab
  json_data = {
    'token_to_idx': token_to_idx,
    'idx_to_token': {v: k for k, v in token_to_idx.iteritems()},
  }
  with open(args.output_json, 'w') as f:
    json.dump(json_data, f)
