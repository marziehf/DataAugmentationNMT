require 'torch'
require 'nn'

require 'mon_LanguageModel'
--require 'mon_LanguageModel_openV' -- open vocab


local cmd = torch.CmdLine()
cmd:option('-checkpoint', 'cv/checkpoint_4000.t7')
cmd:option('-length', 10)
cmd:option('-start_text', '')
cmd:option('-sample', 0)
cmd:option('-temperature', 1)
cmd:option('-gpu', 0)
cmd:option('-gpu_backend', 'cuda')
cmd:option('-verbose', 0)
cmd:option('-topk', 100)
cmd:option('-vocabfreq', './vocab_freq.trg.txt')
cmd:option('-bwd', 0)
local opt = cmd:parse(arg)
local utils = require 'util.utils'

local checkpoint = torch.load(opt.checkpoint)
local model = checkpoint.model

local msg
if opt.gpu >= 0 and opt.gpu_backend == 'cuda' then
  require 'cutorch'
  require 'cunn'
  cutorch.setDevice(opt.gpu + 1)
  model:cuda()
  msg = string.format('Running with CUDA on GPU %d', opt.gpu)
elseif opt.gpu >= 0 and opt.gpu_backend == 'opencl' then
  require 'cltorch'
  require 'clnn'
  model:cl()
  msg = string.format('Running with OpenCL on GPU %d', opt.gpu)
else
  msg = 'Running in CPU mode'
end
if opt.verbose == 1 then print(msg) end

model:evaluate()

if #opt.start_text > 0 then
    local start_corpus = utils.readstartingtext(opt.start_text)
    local sample
    for i=1, #start_corpus do
        opt.start_text = start_corpus[i]
        opt.length = #(start_corpus[i]:split(" ")) --MOI: only generate substitutions for words that are already in the test sentence
--      io.write(opt.start_text)
        sample = model:sample(opt)
        print(sample)
        collectgarbage();
    end
else
    sample = model:sample(opt)
    print(sample)
end

