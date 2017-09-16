# DataAugmentationNMT

This repository includes the codes and scripts for data augmentation targeting rare words for neural machine translation proposed in [our paper](https://www.aclweb.org/anthology/P/P17/P17-2090.pdf).

## Citation

If you use this code, please cite:
```
@InProceedings{fadaee-bisazza-monz:2017:Short2,
  author    = {Fadaee, Marzieh  and  Bisazza, Arianna  and  Monz, Christof},
  title     = {Data Augmentation for Low-Resource Neural Machine Translation},
  booktitle = {Proceedings of the 55th Annual Meeting of the Association for Computational Linguistics (Volume 2: Short Papers)},
  month     = {July},
  year      = {2017},
  address   = {Vancouver, Canada},
  publisher = {Association for Computational Linguistics},
  pages     = {567--573},
  url       = {http://aclweb.org/anthology/P17-2090}
}
```
## Dependencies
* Torch7
* nn
* optim
* lua-cjson
* torch-hdf5
* Python 2.7 

## Usage
### Step 1: Data Preprocessing

Before training the monolingual language model in [src/trg] you'll need to preprocess the data for both forward and backward direction using `preprocess.no_preset_v.py`. 
```
python src/preprocess.no_preset_v.py --train_txt ./wiki.train.txt \
--val_txt ./wiki.val.txt --test_txt ./wiki.test.txt \
--output_h5 ./data.h5 --output_json ./data.json
```
This will produce files `data.h5` and `data.json` that will be passed to the training script.

### Step 2: Language Model Training

After preprocessing the data you'll need to train two language models in forward and backward directions.
```
th src/train.lua -input_h5 data.h5 -input_json data.json \
-checkpoint_name models_rnn/cv  -vocabfreq vocab_freq.trg.txt 

th src/train.lua -input_h5 data.rev.h5 -input_json data.rev.json \
-checkpoint_name models_rnn_rev/cv  -vocabfreq vocab_freq.trg.txt
```
There are many more flags you can use to configure training. 

The `vocabfreq` input is the frequency list of words in the low-resource setting that need augmentation later on using these language models. The format is:
```
...
change 3028
taken 3007
large 2999
again 2994
...
```

### Step 3: Substitution Generation

After training the language models you can generate new sentences in your bitext for [src\trg]. You can run this:
```
th src/substitution.lua -checkpoint models_rnn/cv_xxx.t7 -start_text train.en \
-vocabfreq vocab_freq.trg.txt -sample 0 -topk 1000 -bwd 0 > train.en.subs

th src/substitution.lua -checkpoint models_rev.rnn/cv_xxx.t7 -start_text train.en.rev \
-vocabfreq vocab_freq.trg.txt -sample 0 -topk 1000 -bwd 1 > train.en.rev.subs
```
`start_text` is the side of the bitext that you are targeting for augmentation of rare words. `vocabfreq` is the frequency list used for detecting rare words. `topk` indicates the maximum number of substitutions you want to have for each position in the sentence. 

Running these two codes will give you augmented corpora with a list of substitutions on one side: `train.en.subs` and `train.en.rev.subs`. In order to find substitions that best match the context, you'll need to find the intersection of these two lists:

```
perl ./scripts/generate_intersect.pl train.en.subs train.en.rev.subs subs.intersect
```
`subs.intersect` contains the substitutions that can be used to augment the bitext. It looks like this:

```
```

### Step 4: Generate Augmented corpora

Using the substitution output, the [trg/src] side of the bitext, the alignment, and the lexical probability file you can generate the augmented corpora. 

You can use [fast_align](https://github.com/clab/fast_align) to obtain alignments for your bitext. The format of the alignment input is:

```
...
0-0 1-10 2-3 2-4 2-5 3-13 4-14 5-8 5-9 6-16 7-14 8-11 10-6 11-7 12-17
0-0 1-0 2-0 2-2 3-1 3-3 4-5 5-5 6-6 8-8 9-9 10-10 11-11
...
```
The lexical probability input can be obtained from a dictionary, or the alignments. The format is:
```
...
safely sicher 0.0051237409068
safemode safemode 1
safeness antikollisionssystem 0.3333333
safer sicherer 0.09545972221228
...
```

In order to generate the augmented bitext you can run:

```
perl ./scripts/data_augmentation.pl subs.intersect train.de alignment.txt lex.txt augmentedOutput
```

This will generate two files: `augmentedOutput.augmented` in [src/trg] and `augmentedOutput.fillout` in [trg/src] language. The first file is the side of the bitext augmented targeting the rare words. The second file is respective translations of the augmented sentences.

If you want to have more than one change in each sentence you can also run:

```
perl ./scripts/data_augmentation_multiplechanges.pl subs.intersect train.de alignment.txt lex.txt augmentedOutput
```

#### An example of the output 

Here is a sentence from the augmented file in [src/trg]:
```
at the same time , the rights of consumers began:604~need to be maintained.
```
and respective sentence from the fillout file in [trg/src]:
```
gleichzeitig begann~müssen die rechte der verbraucher geschützt werden .
```

In the augmented file the word *began* with frequncy *604* substitutes the word *need*. In the fillout file the translation of the word, *begann*, substitutes the original word *müssen*.


### Step 5: Generate Clean Bitext for Translation 

To remove all markups and have clean bitext that can be used for translation training you can run:

```
perl ./scripts/filter_out_augmentations.pl augmentedOutput.en augmentedOutput.de 1000
```
You can impose further frequncy limit on rare words you want to augment here. 

## TODO
Update README

## Acknowledgments

In this work this code is utilized:

- Justin Johnson's [torch-rnn](https://github.com/jcjohnson/torch-rnn)
