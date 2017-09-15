require 'torch'
require 'nn'

--require 'mon_LanguageModel'
require 'mon_LanguageModel_lmscore'

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
cmd:option('-vocabfreq', '/datastore/mfadaee1/lstm/vocab_freq.trg.txt')
cmd:option('-bwd', 0)
cmd:option('-wordList', '/datastore/mfadaee1/lstm/rarewords.txt')
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
    --print(opt.start_text)
--    local start_corpus = utils.readstartingtext(opt.start_text)
    local f = io.open(opt.start_text, 'r')
    for line in f:lines() do
        if string.len(line) > 2 then
            opt.start_text = line
--            print(line)
            model:sample(opt)   
        end
    --local words = line:split(" ")
         --for j=1, #words do
         --   print(words[j])
         --   if string.find(words[j], "~") ~= nil then
         --       local cands = words[j]:split("~")
         --       for k=1, #cands do
         --           local curr_cand = string.gsub(line, words[j], cands[k])
         --           print (curr_cand)
         --       end
         --   end
         --   print('\n')
         --   collectgarbage()
       -- end
    end
    f:close()
end

