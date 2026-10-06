import os
import re
import difflib
import pandas as pd
from typing import Dict, Tuple, Optional, Any

TYPOLOGY_CLASSES = [
    "prize_or_fee_scam",
    "investment_scam",
    "romance_scam",
    "impersonation",
    "fake_invoice_or_selling_scam",
    "other_suspicious",
    "none"
]

SUBTYPE_TO_TYPOLOGY = {
    "prize_scam": "prize_or_fee_scam",
    "task_scam": "prize_or_fee_scam",
    "novel_deepfake": "prize_or_fee_scam",
    "crypto_scam": "investment_scam",
    "ponzi": "investment_scam",
    "loan_scam": "investment_scam",
    "novel_crypto": "investment_scam",
    "novel_ai_scam": "investment_scam",
    "novel_equity_scam": "investment_scam",
    "novel_esg_ponzi": "investment_scam",
    "novel_romance": "romance_scam",
    "impersonation": "impersonation",
    "novel_gov_impersonation": "impersonation",
    "novel_regulatory": "impersonation",
    "novel_tax_scam": "impersonation",
    "novel_telecom": "impersonation",
    "novel_recovery": "impersonation",
    "novel_ecommerce": "fake_invoice_or_selling_scam",
    "mule": "other_suspicious",
    "novel_mule": "other_suspicious",
    "novel_visa_mule": "other_suspicious",
    "novel_extortion": "other_suspicious",
    "novel_gambling": "other_suspicious",
    "novel_recruitment": "other_suspicious",
    "novel_customs": "other_suspicious",
    "novel_diplomatic": "other_suspicious",
    "novel_inheritance": "other_suspicious",
    "novel_pawn_scam": "other_suspicious",
}

# Handwritten C4 rows mapping
HANDWRITTEN_TYPOLOGIES = {
    25: ("investment_scam", "en"),
    26: ("prize_or_fee_scam", "en"),
    27: ("prize_or_fee_scam", "taglish"),
    28: ("investment_scam", "en"),
    29: ("prize_or_fee_scam", "en"),
    30: ("investment_scam", "en"),
    31: ("other_suspicious", "taglish"),
    32: ("prize_or_fee_scam", "en"),
    33: ("impersonation", "en"),
    34: ("impersonation", "en"),
    35: ("prize_or_fee_scam", "en"),
    36: ("prize_or_fee_scam", "en"),
    37: ("other_suspicious", "en"),
    38: ("investment_scam", "en"),
    39: ("impersonation", "en"),
    40: ("other_suspicious", "en"),
    41: ("other_suspicious", "en"),
    42: ("impersonation", "en"),
    43: ("investment_scam", "en"),
    44: ("prize_or_fee_scam", "en"),
}

def normalize_text(text: str) -> str:
    if not text:
        return ""
    t = re.sub(r"\s*-\s*Ref\s*#\d+", "", text, flags=re.IGNORECASE)
    t = re.sub(r"[^a-zA-Z0-9\s]", "", t).lower().strip()
    t = re.sub(r"\s+", " ", t)
    return t

class TypologyLabelAnnotator:
    def __init__(self, seeds_dir: Optional[str] = None):
        if not seeds_dir:
            seeds_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "seeds")
        
        self.train_seeds = pd.read_csv(os.path.join(seeds_dir, "memo_seed_train.csv"))
        self.heldout_seeds = pd.read_csv(os.path.join(seeds_dir, "memo_heldout_independent.csv"))
        self.hw_seeds = pd.read_csv(os.path.join(seeds_dir, "handwritten_heldout.csv"))
        
        # Build normalized seed index
        self.seed_lookup = {}
        for df, is_heldout in [(self.train_seeds, False), (self.heldout_seeds, True)]:
            for _, r in df.iterrows():
                raw = str(r["memo"])
                norm = normalize_text(raw)
                sig = str(r["signal"]).lower()
                st = str(r.get("subtype", "generic")).lower()
                lang = str(r.get("language", "en")).lower()
                
                if sig == "scam":
                    typ = SUBTYPE_TO_TYPOLOGY.get(st, "other_suspicious")
                else:
                    typ = "none"
                    
                self.seed_lookup[norm] = {
                    "raw_memo": raw,
                    "signal": sig,
                    "typology": typ,
                    "language": lang,
                    "subtype": st
                }
                
        # Handwritten rows
        self.hw_lookup = {}
        for idx, r in self.hw_seeds.iterrows():
            raw = str(r["memo"])
            norm = normalize_text(raw)
            sig = str(r["label"]).lower()
            if idx in HANDWRITTEN_TYPOLOGIES:
                typ, lang = HANDWRITTEN_TYPOLOGIES[idx]
            else:
                typ = "none"
                # Detect language for legit/neutral handwritten
                if any(w in norm for w in ["pambayad", "bunso", "buwan", "nanay", "palengke", "lola", "ambag", "pang"]):
                    lang = "tl" if any(w in norm for w in ["bunso", "buwan", "nanay", "palengke"]) else "taglish"
                elif any(w in norm for w in ["blowout", "share", "bayad", "ambagan"]):
                    lang = "taglish"
                else:
                    lang = "en"
            self.hw_lookup[norm] = {
                "raw_memo": raw,
                "signal": sig,
                "typology": typ,
                "language": lang,
                "subtype": "handwritten"
            }

    def annotate_memo(self, memo: str, memo_signal: str = "none") -> Dict[str, Any]:
        """Resolves ground truth typology and language for any memo string."""
        if not memo or str(memo).strip() == "" or memo_signal == "none":
            return {"typology": "none", "language": "en", "signal": "none"}
            
        norm = normalize_text(memo)
        if norm in self.hw_lookup:
            return self.hw_lookup[norm]
        if norm in self.seed_lookup:
            return self.seed_lookup[norm]
            
        # Fuzzy match to handle synthetic typos
        all_candidates = list(self.seed_lookup.keys()) + list(self.hw_lookup.keys())
        matches = difflib.get_close_matches(norm, all_candidates, n=1, cutoff=0.60)
        if matches:
            best_match = matches[0]
            if best_match in self.hw_lookup:
                return self.hw_lookup[best_match]
            return self.seed_lookup[best_match]
            
        # Fallback if unmapped
        sig = str(memo_signal).lower()
        typ = "none" if sig in ("legit", "neutral") else "other_suspicious"
        return {"typology": typ, "language": "en", "signal": sig}

    def annotate_dataframe(self, df: pd.DataFrame) -> pd.DataFrame:
        """Adds gt_typology and language columns to a dataset DataFrame."""
        out = df.copy()
        typs = []
        langs = []
        for _, row in out.iterrows():
            m = str(row.get("memo", ""))
            sig = str(row.get("memo_signal", "none"))
            ann = self.annotate_memo(m, sig)
            typs.append(ann["typology"])
            langs.append(ann["language"])
        out["gt_typology"] = typs
        out["language"] = langs
        return out

if __name__ == "__main__":
    annotator = TypologyLabelAnnotator()
    for s in ["T", "V", "C1", "C2", "C4"]:
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "splits", f"{s}.parquet")
        df = pd.read_parquet(path)
        ann_df = annotator.annotate_dataframe(df)
        memo_present = ann_df[ann_df["memo_present"]]
        print(f"Split {s}: {len(memo_present)} memo rows.")
        print("  Typology counts:\n", memo_present["gt_typology"].value_counts().to_dict())
        print("  Language counts:\n", memo_present["language"].value_counts().to_dict())
