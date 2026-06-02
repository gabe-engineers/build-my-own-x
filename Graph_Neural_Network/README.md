# Graph Neural Network

This folder contains notes and notebooks for building up intuition about graph neural networks, starting from a simple baseline and then adding message passing.

## Motivation

There are a lot of interesting breakthroughs in AI that are driven by better inductive biases and better compute efficiency. Weather forecasting is a good example: the climate is a dynamic, complex system, and recent neural approaches have shown that neural networks can model parts of that complexity very effectively. That makes GNNs interesting because they are designed for structured data where relationships matter just as much as the features on individual items.

## What A GNN Operates On

A graph is usually described in terms of:

- nodes
- edges
- optional global context

A useful definition is:

> A GNN is an optimizable transformation on graph attributes that preserves graph symmetries, especially permutation invariance.

In PyTorch Geometric, a graph is commonly represented with fields such as:

`Data(x, edge_index, y, train_mask, val_mask, test_mask)`

- `x`: node features
- `edge_index`: source and destination node indices for each edge
- `y`: labels or targets
- `train_mask`: boolean mask for training examples
- `val_mask`: boolean mask for validation examples
- `test_mask`: boolean mask for test examples

## Simplest Version

The simplest baseline is to apply linear layers to node representations without really using graph connectivity inside the intermediate layers. In that setup, the graph structure only shows up when you aggregate node embeddings at the end.

A common way to make a prediction is to pool neighboring node embeddings with an aggregation function such as:

- mean
- sum
- max

That pooled representation can then be passed to a final linear layer for prediction.

Implementation notebook: [GNNs.ipynb](GNNs.ipynb)

## With Message Passing

The main limitation of the simple baseline is that connectivity is mostly ignored until prediction time. Message passing improves this by letting nodes exchange information during the model's intermediate layers, so the learned representation at each node is shaped by its neighborhood.

Implementation notebook: [GNN_Message_Passing.ipynb](GNN_Message_Passing.ipynb)
