import os
import sys
import numpy as np
import pandas as pd
import onnxruntime as ort
from tokenizers import Tokenizer
from sklearn.metrics import classification_report, f1_score
from sklearn.linear_model import LogisticRegression

# Let's inspect T memo-present rows
df_t = pd.read_parquet('hybrid_bench/data/splits/T.parquet')
t_memos = df_t[df_t['memo_present']].copy()
print(f"Total memo-present in T: {len(t_memos)}")
print(t_memos['memo_signal'].value_counts())
