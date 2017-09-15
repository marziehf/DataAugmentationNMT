require 'torch'
require 'nn'
--require 'trim'

require 'LSTM'

local utils = require 'util.utils'
local LM, parent = torch.class('nn.LanguageModel', 'nn.Module')

function LM:__init(kwargs)
  self.idx_to_token = utils.get_kwarg(kwargs, 'idx_to_token')
  self.freqs = utils.get_kwarg(kwargs, 'vocabfreq')
  print('LM initing ...')
  self.token_to_idx = {}
  self.vocab_size = 0
  for idx, token in pairs(self.idx_to_token) do
    self.token_to_idx[token] = idx
    self.vocab_size = self.vocab_size + 1
  end
  self.bwd = utils.get_kwarg(kwargs, 'bwd', 0) 
  self.model_type = utils.get_kwarg(kwargs, 'model_type')
  self.wordvec_dim = utils.get_kwarg(kwargs, 'wordvec_size')
  self.rnn_size = utils.get_kwarg(kwargs, 'rnn_size')
  self.num_layers = utils.get_kwarg(kwargs, 'num_layers')
  self.dropout = utils.get_kwarg(kwargs, 'dropout')
  self.batchnorm = utils.get_kwarg(kwargs, 'batchnorm')

  local V, D, H = self.vocab_size, self.wordvec_dim, self.rnn_size
  print('V D H: '.. V ..' '..D..' '..H) --688784 64 128
  self.net = nn.Sequential()
  self.rnns = {}
  self.bn_view_in = {}
  self.bn_view_out = {}

  self.net:add(nn.LookupTable(V, D))
  for i = 1, self.num_layers do
    local prev_dim = H
    if i == 1 then prev_dim = D end
    local rnn = nn.LSTM(prev_dim, H)
    rnn.remember_states = true
    table.insert(self.rnns, rnn)
    self.net:add(rnn)
    if self.batchnorm == 1 then  
      local view_in = nn.View(1, 1, -1):setNumInputDims(3)
      table.insert(self.bn_view_in, view_in)
      self.net:add(view_in)
      self.net:add(nn.BatchNormalization(H))
      local view_out = nn.View(1, -1):setNumInputDims(2)
      table.insert(self.bn_view_out, view_out)
      self.net:add(view_out)
    end
    if self.dropout > 0 then
      self.net:add(nn.Dropout(self.dropout))
    end
  end

  -- After all the RNNs run, we will have a tensor of shape (N, T, H);
  -- we want to apply a 1D temporal convolution to predict scores for each
  -- vocab element, giving a tensor of shape (N, T, V). Unfortunately
  -- nn.TemporalConvolution is SUPER slow, so instead we will use a pair of
  -- views (N, T, H) -> (NT, H) and (NT, V) -> (N, T, V) with a nn.Linear in
  -- between. Unfortunately N and T can change on every minibatch, so we need
  -- to set them in the forward pass.
  self.view1 = nn.View(1, 1, -1):setNumInputDims(3)
  self.view2 = nn.View(1, -1):setNumInputDims(2)

  self.net:add(self.view1)
  self.net:add(nn.Linear(H, V))
  self.net:add(self.view2)
end


function LM:updateOutput(input)
  local N, T = input:size(1), input:size(2)
  self.view1:resetSize(N * T, -1)
  self.view2:resetSize(N, T, -1)

  for _, view_in in ipairs(self.bn_view_in) do
    view_in:resetSize(N * T, -1)
  end
  for _, view_out in ipairs(self.bn_view_out) do
    view_out:resetSize(N, T, -1)
  end

  return self.net:forward(input)
end


function LM:backward(input, gradOutput, scale)
  return self.net:backward(input, gradOutput, scale)
end


function LM:parameters()
  return self.net:parameters()
end


function LM:training()
  self.net:training()
  parent.training(self)
end


function LM:evaluate()
  self.net:evaluate()
  parent.evaluate(self)
end


function LM:resetStates()
  for i, rnn in ipairs(self.rnns) do
    rnn:resetStates()
  end
end

function has_word (tab, val)
    for i, v in pairs (tab) do
        if i == val then
            return true
        end
    end
    return false
end

function LM:encode_string(content)
  local words = content:split(" ")  
  local encoded = torch.LongTensor(#words)
  for i=1, #words do
    local idx;
    if has_word (self.token_to_idx, words[i]) then
       idx = self.token_to_idx[words[i]]
    else
       idx = self.token_to_idx['unk'] 
    end
    assert(idx ~= nil, 'Got invalid idx')
    encoded[i] = idx
  end
  return encoded
end


function LM:decode_string(encoded, candidates, first_T)
  assert(torch.isTensor(encoded) and encoded:dim() == 1)
  local s = ''
  if self.bwd == 0 then
    for i = 1, encoded:size(1) do
        local idx = encoded[i]
        local token = self.idx_to_token[idx]
        --s = s .. token .. ' '
        io.write(token .. ' ')
        s = s .. token .. ' {'
        local current = candidates:select(2,i)
        for j=1, current:size(1) do
              if current[j] ~= 0 and self.freqs[self.idx_to_token[idx]] ~= nil then -- index 0 maps to nil
                local num = tonumber(self.freqs[self.idx_to_token[idx]])               
                if self.freqs[self.idx_to_token[current[j]]] ~= nil and tonumber(self.freqs[self.idx_to_token[current[j]]]) < 1000 then--num * 0.01  then
                    s = s .. self.idx_to_token[current[j]] .. ':' .. self.freqs[self.idx_to_token[current[j]]] .. ' '
                end
            end
        end
        s = s .. '}\n' 
    end
  else
    for i=encoded:size(1),1,-1 do
        local idx = encoded[i]
        local token = self.idx_to_token[idx]
        --s = s .. token .. ' '
        io.write(token .. ' ')
        s = s .. token .. ' {'
        local current = candidates:select(2,i)
        for j=1, current:size(1) do
            if current[j] ~= 0 and self.freqs[self.idx_to_token[idx]] ~= nil then -- index 0 maps to nil
                local num = tonumber(self.freqs[self.idx_to_token[idx]])
                if self.freqs[self.idx_to_token[current[j]]] ~= nil and tonumber(self.freqs[self.idx_to_token[current[j]]]) < 1000 then--num * 0.01  then
                   s = s .. self.idx_to_token[current[j]] .. ':' .. self.freqs[self.idx_to_token[current[j]]] .. ' '
                end
            end
        end
        s = s .. '}\n' 
    end
  end
  io.write('\n')
  collectgarbage();
  return s
end


--[[
Sample from the language model. Note that this will reset the states of the
underlying RNNs.

Inputs:
- init: String of length T0
- max_length: Number of characters to sample

Returns:
- sampled: (1, max_length) array of integers, where the first part is init.
--]]
function LM:sample(kwargs)
  local start_text = utils.get_kwarg(kwargs, 'start_text', '')
  local T = utils.get_kwarg(kwargs, 'length', 10)
  local verbose = utils.get_kwarg(kwargs, 'verbose', 0)
  local sample = utils.get_kwarg(kwargs, 'sample', 0)
  local temperature = utils.get_kwarg(kwargs, 'temperature', 1)
  local TOPK = utils.get_kwarg(kwargs, 'topk', 5)
  local candidates = torch.LongTensor(TOPK, T)
  local sampled = torch.LongTensor(1, T) 
  local fff = utils.get_kwarg(kwargs, 'vocabfreq')
  self.freqs = utils.readtxt(fff)
  self.bwd = utils.get_kwarg(kwargs, 'bwd', 0)
  self:resetStates()
  local w = self.net:get(1).weight
  local scores = w.new(1, 1, self.vocab_size):fill(1)

  local first_t = 1
  local x = self:encode_string(start_text)
          
  local two, options = nil, nil
  local next_char = torch.Tensor(1,1)

  for t = first_t, T do
     two, options = scores:topk(TOPK, true)    
     options = options:resize(TOPK)
     next_char[1][1] = x[t]
     sampled[{{}, {t, t}}]:copy(next_char)
     candidates[{{}, t}]:copy(options)
     scores = self:forward(next_char)
  end 

  self:resetStates()
  return self:decode_string(sampled[1], candidates, first_t)
end


function LM:clearState()
  self.net:clearState()
end
