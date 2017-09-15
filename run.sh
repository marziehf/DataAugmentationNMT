#preprocess
python ./src/preprocess.no_preset_v.py --train_txt ./train.en --val_txt ./val.en --test_txt ./test.en --output_h5 ./data.en.h5 --output_json ./data.en.json
cat data.txt | awk '{for (i=NF; i>0; i--) {printf "%s ", $i;} printf "\n" }' > data.rev.txt
python ./src/preprocess.no_preset_v.py --train_txt ./train.en.rev --val_txt ./val.en.rev --test_txt ./test.en.rev --output_h5 ./data.en.rev.h5 --output_json ./data.en.rev.json
#
#train rnn-LM
th ./src/train.lua -input_h5 ./data.h5 -input_json ./data.json -checkpoint_name ./models_rnn/cv  -vocabfreq ./vocab_freq.trg.txt 
th ./src/train.lua -input_h5 ./data.rev.h5 -input_json ./data.rev.json -checkpoint_name ./models_rnn_rev/cv  -vocabfreq ./vocab_freq.trg.txt

#generate subs
th ./src/substitution.lua -checkpoint ./models_rnn/cv_xxx.t7 -start_text ./train.en -vocabfreq ./vocab_freq.trg.txt -sample 0 -topk 1000 -bwd 0 > train.en.subs
th ./src/substitution.lua -checkpoint ./models_rev.rnn/cv_xxx.t7 -start_text ./train.en.rev -vocabfreq ./vocab_freq.trg.txt -sample 0 -topk 1000 -bwd 1 > train.en.rev.subs
perl ./scripts/generate_intersect.pl train.en.subs train.en.rev.subs subs.intersect

#generate augmented sentences
perl ./scripts/data_augmentation.pl subs.intersect train.de alignment.txt lex.txt augmentedOutput
perl ./scripts/data_augmentation_multiplechanges.pl subs.intersect train.de alignment.txt lex.txt augmentedOutput

#generate clean augmented bitext 
perl ./scripts/filter_out_augmentations.pl augmentedOutput.en augmentedOutput.de 1000

#cluster rare words
perl ./scripts/cluster_rarewords.pl augmentedOutput.en augmentedOutput.de clusters.en 1000
