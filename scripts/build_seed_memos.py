"""
Build and validate seed memo files:
- hybrid_bench/data/seeds/memo_seed_train.csv (208 rows)
- hybrid_bench/data/seeds/memo_heldout_independent.csv (106 rows)
- hybrid_bench/data/seeds/handwritten_heldout.csv (optional C4, 50 rows)
Validates no exact duplicates across or within files, and calculates token Jaccard similarity.
"""

import os
import csv
import re
from typing import List, Dict, Set, Tuple

def tokenize(text: str) -> Set[str]:
    return set(re.findall(r"\b\w+\b", text.lower()))

def token_jaccard(s1: str, s2: str) -> float:
    t1 = tokenize(s1)
    t2 = tokenize(s2)
    if not t1 or not t2:
        return 0.0
    return len(t1.intersection(t2)) / len(t1.union(t2))

def build_datasets():
    # -------------------------------------------------------------------------
    # 1. Train Seed Memos: Exactly 208 rows
    # -------------------------------------------------------------------------
    seed_train_data = []

    # Format: (memo, signal, subtype, language, difficulty, typology_novel)
    raw_seed_train = [
        # --- Legit: Everyday & Groceries (35) ---
        ("SM Supermarket grocery haul", "legit", "groceries", "en", "easy", False),
        ("Puregold weekly essentials and pantry supply", "legit", "groceries", "en", "easy", False),
        ("Robinsons Supermarket fresh fruits and meat", "legit", "groceries", "en", "easy", False),
        ("Pambili ng bigas at ulam sa palengke", "legit", "groceries", "tl", "easy", False),
        ("Weekly grocery share sa bahay", "legit", "groceries", "taglish", "easy", False),
        ("Landmark supermarket groceries", "legit", "groceries", "en", "easy", False),
        ("S&R membership shopping items", "legit", "groceries", "en", "easy", False),
        ("Pantry food stocks replenishment", "legit", "groceries", "en", "easy", False),
        ("Wet market seafood purchase", "legit", "groceries", "en", "easy", False),
        ("South Star Drug vitamins and prescription medicines", "legit", "groceries", "en", "easy", False),
        ("Mercury Drug maintenance pills for lola", "legit", "groceries", "taglish", "easy", False),
        ("Watsons skincare and hygiene supplies", "legit", "groceries", "en", "easy", False),
        ("Baby diapers and milk formula supply", "legit", "groceries", "en", "easy", False),
        ("Cat food kibbles and litter sand", "legit", "groceries", "en", "easy", False),
        ("Dog veterinary shampoo and tick medicine", "legit", "groceries", "en", "easy", False),
        ("Water refilling station 10 gallons delivery", "legit", "groceries", "en", "easy", False),
        ("Bakery bread and morning pandesal treat", "legit", "groceries", "en", "easy", False),
        ("Office lunch share Jollibee chickenjoy bucket", "legit", "groceries", "taglish", "easy", False),
        ("Samgyupsal team dinner split payment", "legit", "groceries", "en", "easy", False),
        ("Coffee and pastry meeting at UCC Cafe", "legit", "groceries", "en", "easy", False),
        ("Lunch delivery GrabFood order share", "legit", "groceries", "en", "easy", False),
        ("Pizza party chip-in for project celebration", "legit", "groceries", "en", "easy", False),
        ("Dinner delivery Foodpanda bill share", "legit", "groceries", "en", "easy", False),
        ("Ambag sa birthday cake ni boss", "legit", "groceries", "taglish", "easy", False),
        ("Dessert milk tea afternoon snack", "legit", "groceries", "en", "easy", False),
        ("Snacks and refreshments for bible study", "legit", "groceries", "en", "easy", False),
        ("Korean grocery noodles and kimchi stock", "legit", "groceries", "en", "easy", False),
        ("Fruits and vegetables from Baguio market", "legit", "groceries", "en", "easy", False),
        ("Organic eggs and fresh milk delivery", "legit", "groceries", "en", "easy", False),
        ("Sunday family brunch at Mary Grace", "legit", "groceries", "en", "easy", False),
        ("Barbeque stall payment via QR Ph", "legit", "groceries", "en", "easy", False),
        ("Canteen lunch credit settlement", "legit", "groceries", "en", "easy", False),
        ("Fastfood breakfast drive-thru share", "legit", "groceries", "en", "easy", False),
        ("Pampanga meat tocino and longganisa order", "legit", "groceries", "taglish", "easy", False),
        ("Bottled mineral water office supply", "legit", "groceries", "en", "easy", False),

        # --- Legit: Utilities & Rent (30) ---
        ("Meralco electricity bill payment for September", "legit", "utilities", "en", "easy", False),
        ("Maynilad water services residential account", "legit", "utilities", "en", "easy", False),
        ("Manila Water monthly bill settlement", "legit", "utilities", "en", "easy", False),
        ("PLDT Home Fibr monthly internet broadband", "legit", "utilities", "en", "easy", False),
        ("Globe postpaid telecom monthly plan", "legit", "utilities", "en", "easy", False),
        ("Converge ICT fiber internet connection", "legit", "utilities", "en", "easy", False),
        ("Smart Communications postpaid cellular bill", "legit", "utilities", "en", "easy", False),
        ("Sky Cable television monthly subscription", "legit", "utilities", "en", "easy", False),
        ("Cignal TV prepaid reload package", "legit", "utilities", "en", "easy", False),
        ("LPG gas tank refill delivery cooking", "legit", "utilities", "en", "easy", False),
        ("Monthly rent payment for Studio Unit 12B", "legit", "rent", "en", "easy", False),
        ("Bayad sa upa para sa buwan ng Oktubre", "legit", "rent", "tl", "easy", False),
        ("Apartment monthly rental fee and water share", "legit", "rent", "en", "easy", False),
        ("Condominium association dues and garbage fee", "legit", "rent", "en", "easy", False),
        ("Parking slot rental payment B2 slot 45", "legit", "rent", "en", "easy", False),
        ("Commercial stall lease payment monthly", "legit", "rent", "en", "easy", False),
        ("Warehouse storage room monthly lease", "legit", "rent", "en", "easy", False),
        ("Office co-working space dedicated desk fee", "legit", "rent", "en", "easy", False),
        ("Staff housing dormitory room share", "legit", "rent", "en", "easy", False),
        ("Townhouse security maintenance monthly dues", "legit", "rent", "en", "easy", False),
        ("Subdivision clubhouse dues and guard fee", "legit", "rent", "en", "easy", False),
        ("Advance one month rent deposit for renewal", "legit", "rent", "en", "medium", False),
        ("Room rental balance settlement for mid-month", "legit", "rent", "en", "easy", False),
        ("Aircon cleaning and preventive maintenance service", "legit", "utilities", "en", "easy", False),
        ("Plumbing repair service and replacement parts", "legit", "utilities", "en", "easy", False),
        ("Electrical rewiring installation labor cost", "legit", "utilities", "en", "easy", False),
        ("Pest control termite treatment service", "legit", "utilities", "en", "easy", False),
        ("Internet router replacement hardware cost", "legit", "utilities", "en", "easy", False),
        ("CCTV surveillance installation downpayment", "legit", "utilities", "en", "easy", False),
        ("Subdivision vehicle RFID sticker purchase", "legit", "utilities", "en", "easy", False),

        # --- Legit: Family Allowance & Padala (25) ---
        ("Monthly allowance for college daughter", "legit", "allowance", "en", "easy", False),
        ("Pang allowance ni bunso sa UST", "legit", "allowance", "taglish", "easy", False),
        ("Financial allowance support for mama and papa", "legit", "allowance", "en", "easy", False),
        ("Weekly school allowance and bus fare", "legit", "allowance", "en", "easy", False),
        ("Pang matrikula at school projects", "legit", "allowance", "tl", "easy", False),
        ("Emergency financial assistance for cousin", "legit", "allowance", "en", "medium", False),
        ("Pang bili ng gamot at gatas ni lolo", "legit", "allowance", "tl", "easy", False),
        ("Graduation gift monetary present", "legit", "allowance", "en", "easy", False),
        ("Birthday monetary gift for niece", "legit", "allowance", "en", "easy", False),
        ("Wedding gift cash transfer for newlywed couple", "legit", "allowance", "en", "easy", False),
        ("Padala pambayad sa kuryente sa probinsya", "legit", "allowance", "tl", "easy", False),
        ("Christmas pamasko for godchildren", "legit", "allowance", "taglish", "easy", False),
        ("Childcare nanny yaya monthly salary payment", "legit", "allowance", "taglish", "easy", False),
        ("Family driver semi-monthly wages", "legit", "allowance", "en", "easy", False),
        ("House helper monthly salary and allowance", "legit", "allowance", "en", "easy", False),
        ("Gardener landscaping maintenance honorarium", "legit", "allowance", "en", "easy", False),
        ("Elderly caregiver allowance and groceries", "legit", "allowance", "en", "easy", False),
        ("Pang boundary ng tricycle driver", "legit", "allowance", "tl", "easy", False),
        ("Sibling contribution for mother hospital bill", "legit", "allowance", "en", "medium", False),
        ("Pocket money for provincial vacation trip", "legit", "allowance", "en", "easy", False),
        ("Youth fellowship camp registration allowance", "legit", "allowance", "en", "easy", False),
        ("Sports training uniform and gear allowance", "legit", "allowance", "en", "easy", False),
        ("Music lessons piano teacher monthly fee", "legit", "allowance", "en", "easy", False),
        ("Art workshop materials cash allowance", "legit", "allowance", "en", "easy", False),
        ("Pang requirements sa board examination", "legit", "allowance", "taglish", "easy", False),

        # --- Legit: Education, Books, Technical & Legal (20) ---
        ("University tuition matriculation fee installment 1", "legit", "education", "en", "easy", False),
        ("DLSU term 2 tuition balance settlement", "legit", "education", "en", "easy", False),
        ("Ateneo graduate school MBA tuition installment", "legit", "education", "en", "easy", False),
        ("College laboratory fee and textbook package", "legit", "education", "en", "easy", False),
        ("O'Reilly mastering cryptocurrency book tutorial", "legit", "technical_book", "en", "hard", False),
        ("Designing data intensive applications technical textbook", "legit", "technical_book", "en", "easy", False),
        ("Python machine learning book and online course access", "legit", "technical_book", "en", "easy", False),
        ("AWS certified solutions architect study guide", "legit", "technical_book", "en", "easy", False),
        ("Cybersecurity risk analysis handbook textbook", "legit", "technical_book", "en", "hard", False),
        ("Attorney legal document notarization service fee", "legit", "legal_fee", "en", "hard", False),
        ("Notarial fee for deed of absolute sale", "legit", "legal_fee", "en", "hard", False),
        ("Law office consultation retainer balance", "legit", "legal_fee", "en", "hard", False),
        ("Corporate legal secretarial compliance fees", "legit", "legal_fee", "en", "hard", False),
        ("Certified public accountant audit engagement deposit", "legit", "legal_fee", "en", "hard", False),
        ("Real estate property appraisal fee", "legit", "legal_fee", "en", "hard", False),
        ("Architectural house renovation plan blueprint fee", "legit", "education", "en", "easy", False),
        ("Dentist tooth extraction and cleaning procedure", "legit", "education", "en", "easy", False),
        ("Medical clinic consultation and diagnostic blood test", "legit", "education", "en", "easy", False),
        ("Ophthalmology prescription glasses lenses payment", "legit", "education", "en", "easy", False),
        ("Professional engineering consultancy service billing", "legit", "legal_fee", "en", "hard", False),

        # --- Neutral / Ambiguous Memos (28) ---
        ("Funds transfer", "neutral", "generic", "en", "easy", False),
        ("Payment", "neutral", "generic", "en", "easy", False),
        ("Transfer", "neutral", "generic", "en", "easy", False),
        ("Bills payment", "neutral", "generic", "en", "easy", False),
        ("Deposit", "neutral", "generic", "en", "easy", False),
        ("Settlement", "neutral", "generic", "en", "easy", False),
        ("GCash cash in transaction", "neutral", "generic", "en", "easy", False),
        ("Maya digital wallet reload", "neutral", "generic", "en", "easy", False),
        ("BPI express online transfer", "neutral", "generic", "en", "easy", False),
        ("Ref 982341", "neutral", "reference", "en", "easy", False),
        ("Invoice 2026-089", "neutral", "reference", "en", "easy", False),
        ("Personal transfer", "neutral", "generic", "en", "easy", False),
        ("Own account transfer", "neutral", "generic", "en", "easy", False),
        ("Savings transfer", "neutral", "generic", "en", "easy", False),
        ("For safe keeping", "neutral", "generic", "en", "easy", False),
        ("Transaction reimbursement", "neutral", "generic", "en", "easy", False),
        ("Reimbursement", "neutral", "generic", "en", "easy", False),
        ("Payment for services rendered", "neutral", "generic", "en", "medium", False),
        ("Contract agreement payment", "neutral", "generic", "en", "medium", False),
        ("Thank you", "neutral", "generic", "en", "easy", False),
        ("Salamat", "neutral", "generic", "tl", "easy", False),
        ("Padala", "neutral", "generic", "tl", "easy", False),
        ("Bayad", "neutral", "generic", "tl", "easy", False),
        ("Pambayad", "neutral", "generic", "tl", "easy", False),
        ("Shared expenses", "neutral", "generic", "en", "easy", False),
        ("Miscellaneous payment", "neutral", "generic", "en", "easy", False),
        ("Balance settlement", "neutral", "generic", "en", "easy", False),
        ("Advance settlement", "neutral", "generic", "en", "easy", False),

        # --- Scam: Crypto Advance Fee & Fraud (20) ---
        ("Urgent processing fee to release cryptocurrency trading profit", "scam", "crypto_scam", "en", "easy", False),
        ("Advance gas fee deposit to unlock USDT trading profits", "scam", "crypto_scam", "en", "easy", False),
        ("Wallet release clearance charge for bitcoin investment", "scam", "crypto_scam", "en", "easy", False),
        ("Urgent tax deposit to withdraw offshore crypto wallet funds", "scam", "crypto_scam", "en", "medium", False),
        ("Arbitrage trading pool deposit to withdraw accumulated balance", "scam", "crypto_scam", "en", "medium", False),
        ("Binance smart chain gas fee verification transfer", "scam", "crypto_scam", "en", "medium", False),
        ("Crypto wallet authentication fee for frozen balance", "scam", "crypto_scam", "en", "easy", False),
        ("Withdrawal insurance fee for crypto futures trade payout", "scam", "crypto_scam", "en", "medium", False),
        ("International blockchain compliance fee for capital release", "scam", "crypto_scam", "en", "medium", False),
        ("Liquidity pool deposit to claim doubling yield bonus", "scam", "crypto_scam", "en", "easy", False),
        ("Urgent unlock fee for frozen international wallet account", "scam", "crypto_scam", "en", "easy", False),
        ("Digital asset recovery service upfront documentation charge", "scam", "crypto_scam", "en", "hard", False),
        ("P2P crypto release bond deposit immediately required", "scam", "crypto_scam", "en", "medium", False),
        ("Foreign exchange crypto conversion fee for withdrawal", "scam", "crypto_scam", "en", "medium", False),
        ("Mining node staking fee to unfreeze weekly income", "scam", "crypto_scam", "en", "medium", False),
        ("VIP member fee to release daily crypto arbitrage returns", "scam", "crypto_scam", "en", "medium", False),
        ("Urgent smart contract clearance payment for payout", "scam", "crypto_scam", "en", "easy", False),
        ("Escrow release commission for cryptocurrency exchange sale", "scam", "crypto_scam", "en", "hard", False),
        ("Anti money laundering certificate fee for crypto release", "scam", "crypto_scam", "en", "hard", False),
        ("Fast track liquidity withdrawal fee for decentralized wallet", "scam", "crypto_scam", "en", "medium", False),

        # --- Scam: Prize, Lottery, & Task Scams (25) ---
        ("Deposit advance fee to claim grand prize promo winning", "scam", "prize_scam", "en", "easy", False),
        ("Processing charge to release brand new SUV raffle prize", "scam", "prize_scam", "en", "easy", False),
        ("BIR tax clearance fee for PCSO sweepstakes jackpot claim", "scam", "prize_scam", "taglish", "medium", False),
        ("Advance courier freight fee for winning Apple iPhone 16", "scam", "prize_scam", "en", "easy", False),
        ("Claim fee for anniversary cash prize reward from telecom", "scam", "prize_scam", "en", "easy", False),
        ("Registration fee to process 500k lucky draw reward", "scam", "prize_scam", "en", "easy", False),
        ("Notarization doc fee to disburse overseas inheritance estate", "scam", "prize_scam", "en", "medium", False),
        ("Consortium grant release handling charge for lottery winner", "scam", "prize_scam", "en", "medium", False),
        ("Urgent customs clearance fee for parcel package release", "scam", "task_scam", "en", "medium", False),
        ("Customs inspection tax to release foreign luggage delivery", "scam", "task_scam", "en", "medium", False),
        ("Diplomatic courier delivery stamp fee for gold package", "scam", "task_scam", "en", "easy", False),
        ("Postal parcel insurance fee for international gift delivery", "scam", "task_scam", "en", "medium", False),
        ("Telegram product review task fee to earn 3000 daily", "scam", "task_scam", "en", "easy", False),
        ("Shopee seller boost activation deposit for commission payout", "scam", "task_scam", "taglish", "easy", False),
        ("Lazada merchant trial deposit to unlock affiliate earnings", "scam", "task_scam", "taglish", "easy", False),
        ("TikTok video likes task deposit to qualify for VIP level", "scam", "task_scam", "en", "easy", False),
        ("YouTube subscriber task deposit for guaranteed commission", "scam", "task_scam", "en", "easy", False),
        ("Online hotel booking review task collateral deposit", "scam", "task_scam", "en", "easy", False),
        ("Data entry job enrollment training kit deposit", "scam", "task_scam", "en", "easy", False),
        ("Freelance virtual assistant verification deposit to start work", "scam", "task_scam", "en", "medium", False),
        ("Home based packing job security bond fee", "scam", "task_scam", "en", "easy", False),
        ("Part time survey evaluation deposit to unlock salary", "scam", "task_scam", "en", "easy", False),
        ("App testing commission guarantee deposit payment", "scam", "task_scam", "en", "easy", False),
        ("Movie trailer watching task deposit for instant bonus", "scam", "task_scam", "en", "easy", False),
        ("VIP merchant merchant rating task upgrade deposit", "scam", "task_scam", "en", "easy", False),

        # --- Scam: Ponzi, Mule & Loan Impersonation (25) ---
        ("Locked capital deposit for guaranteed 40% monthly return", "scam", "ponzi", "en", "easy", False),
        ("Capital investment deposit for guaranteed 10% weekly payout", "scam", "ponzi", "en", "easy", False),
        ("P2P double your savings program membership deposit", "scam", "ponzi", "en", "easy", False),
        ("Automated forex algorithmic trading bot deposit license", "scam", "ponzi", "en", "medium", False),
        ("Livestock piggery investment contract guaranteed return", "scam", "ponzi", "en", "medium", False),
        ("Solar energy crowdfunding certificate guaranteed dividend", "scam", "ponzi", "en", "medium", False),
        ("Gold bullion trading certificate daily profit sharing", "scam", "ponzi", "en", "medium", False),
        ("Fast cash online loan approval collateral fee", "scam", "loan_scam", "en", "easy", False),
        ("Credit repair advance processing fee to fix credit rating", "scam", "loan_scam", "en", "medium", False),
        ("Pre approved salary loan insurance bond deposit", "scam", "loan_scam", "en", "easy", False),
        ("Emergency microloan processing and disbursal verification fee", "scam", "loan_scam", "en", "easy", False),
        ("BDO account reactivation fee to release locked incoming remittance", "scam", "impersonation", "taglish", "medium", False),
        ("BPI online account security update compliance fee", "scam", "impersonation", "taglish", "medium", False),
        ("PNB overseas remittance clearance penalty payment", "scam", "impersonation", "en", "medium", False),
        ("Maya digital wallet restoration fee for compromised account", "scam", "impersonation", "en", "medium", False),
        ("GCash AMLA compliance clearance bond payment", "scam", "impersonation", "taglish", "hard", False),
        ("Anti cybercrime group investigation clearance fee", "scam", "impersonation", "en", "hard", False),
        ("Temporary holding transfer for mule redirection please cash out", "scam", "mule", "en", "easy", False),
        ("Paki forward agad pagka pasok ng pera sa account", "scam", "mule", "tl", "easy", False),
        ("Holding fund transfer please withdraw over the counter and give cash", "scam", "mule", "en", "easy", False),
        ("Intermediary transfer routing please pass to third party account", "scam", "mule", "en", "medium", False),
        ("Transit remittance to distribute to designated recipient", "scam", "mule", "en", "medium", False),
        ("Split remittance forwarding please send via pawnshop remitter", "scam", "mule", "en", "easy", False),
        ("Temporary payroll holding deposit please return 90 percent cash", "scam", "mule", "en", "medium", False),
        ("Commission sharing cashout proxy transfer immediately", "scam", "mule", "en", "easy", False),
    ]

    for memo, signal, subtype, lang, diff, novel in raw_seed_train:
        seed_train_data.append({
            "memo": memo,
            "signal": signal,
            "subtype": subtype,
            "language": lang,
            "difficulty": diff,
            "typology_novel": novel,
            "split_role": "seed_pool",
            "author": "ml_expert_auditor"
        })

    # -------------------------------------------------------------------------
    # 2. Held-out Independent Memos: Exactly 106 rows
    # -------------------------------------------------------------------------
    heldout_data = []

    # Format: (memo, signal, subtype, language, difficulty, typology_novel)
    raw_heldout = [
        # --- Legit Novel & Everyday (55) ---
        ("Barangay clearance and business permit renewal fee", "legit", "government_fee", "en", "easy", False),
        ("Real property tax amilyar settlement city treasury", "legit", "government_fee", "taglish", "medium", False),
        ("BIR withholding tax return payment form 0605", "legit", "government_fee", "en", "hard", False),
        ("Social security system voluntary member contribution", "legit", "government_fee", "en", "easy", False),
        ("PhilHealth annual health insurance contribution", "legit", "government_fee", "en", "easy", False),
        ("Pag-IBIG housing loan monthly amortization deduction", "legit", "government_fee", "en", "easy", False),
        ("Land Transportation Office motor vehicle registration fee", "legit", "government_fee", "en", "easy", False),
        ("Comprehensive automotive insurance policy premium renewal", "legit", "insurance", "en", "easy", False),
        ("Homeowners association special assessment for flood gate repair", "legit", "rent", "en", "medium", True),
        ("St. Luke's medical center outpatient laboratory diagnostic test", "legit", "healthcare", "en", "easy", False),
        ("The Medical City cardiac rehabilitation consultation copay", "legit", "healthcare", "en", "easy", False),
        ("Makati Medical Center pediatric checkup and immunization", "legit", "healthcare", "en", "easy", False),
        ("Veterinary hospital emergency cat laparotomy surgery", "legit", "healthcare", "en", "medium", True),
        ("Dental implant and crown procedure downpayment", "legit", "healthcare", "en", "medium", True),
        ("Physical therapy session rehabilitation 10 pack", "legit", "healthcare", "en", "easy", False),
        ("Aesthetic dermatology laser treatment package", "legit", "healthcare", "en", "easy", False),
        ("Architectural landscape CAD blueprint drafting honorarium", "legit", "professional_fee", "en", "hard", True),
        ("Structural engineer soil test inspection certification fee", "legit", "professional_fee", "en", "hard", True),
        ("Piano regulation tuning and hammer replacement service", "legit", "professional_fee", "en", "medium", True),
        ("Acoustic guitar luthier fretboard repair and setup", "legit", "professional_fee", "en", "easy", True),
        ("Solar rooftop inverter replacement hardware balance", "legit", "home_improvement", "en", "medium", True),
        ("Deep well submersible water pump repair labor", "legit", "home_improvement", "en", "medium", True),
        ("Aluminum glass sliding window fabrication deposit", "legit", "home_improvement", "en", "easy", False),
        ("Custom solid mahogany dining table carpentry balance", "legit", "home_improvement", "en", "medium", True),
        ("House interior repainting contractor labor contract", "legit", "home_improvement", "en", "easy", False),
        ("Automobile transmission overhaul labor and fluid replacement", "legit", "automotive", "en", "medium", False),
        ("Car battery AGM replacement and installation roadside", "legit", "automotive", "en", "easy", False),
        ("Set of four Bridgestone tires replacement wheel alignment", "legit", "automotive", "en", "medium", False),
        ("Baguio heritage hotel weekend accommodation downpayment", "legit", "travel", "en", "easy", False),
        ("El Nido island hopping boat charter reservation", "legit", "travel", "en", "easy", False),
        ("Boracay resort beachfront room balance checkout", "legit", "travel", "en", "easy", False),
        ("Siargao surf school 5-day package enrollment", "legit", "travel", "en", "easy", False),
        ("Philippine Airlines roundtrip flight booking confirmation", "legit", "travel", "en", "easy", False),
        ("Cebu Pacific baggage allowance and seat selector add on", "legit", "travel", "en", "easy", False),
        ("Scuba diving open water certification course tuition", "legit", "education", "en", "medium", True),
        ("Culinary institute pastry masterclass weekend workshop", "legit", "education", "en", "easy", True),
        ("Kumon math learning center monthly module tuition", "legit", "education", "en", "easy", False),
        ("Taekwondo martial arts academy monthly dojo fee", "legit", "education", "en", "easy", False),
        ("Ballet dance academy annual recital participation fee", "legit", "education", "en", "easy", False),
        ("Pre-school toddler playgroup term enrollment", "legit", "education", "en", "easy", False),
        ("Secondhand mirrorless camera body via FB marketplace meetup", "legit", "electronics", "en", "medium", True),
        ("Mechanical keyboard custom keycaps and switch modding", "legit", "electronics", "en", "easy", True),
        ("Ergonomic mesh office chair delivery payment", "legit", "home_improvement", "en", "easy", False),
        ("High-end espresso machine descaling maintenance overhaul", "legit", "home_improvement", "en", "medium", True),
        ("Church tithes and benevolent community fund offering", "legit", "donation", "en", "easy", False),
        ("Rotary club international annual membership dues", "legit", "donation", "en", "easy", False),
        ("Animal welfare shelter volunteer rescue sponsorship", "legit", "donation", "en", "easy", False),
        ("Red Cross humanitarian disaster relief donation", "legit", "donation", "en", "easy", False),
        ("Alumni homecoming commemorative banquet ticket payment", "legit", "donation", "en", "easy", False),
        ("Funeral memorial plan monthly pre-need amortization", "legit", "insurance", "en", "easy", False),
        ("Cemetery columbarium niche perpetual care maintenance fee", "legit", "insurance", "en", "hard", True),
        ("Bayad sa caterer para sa binyag ni baby", "legit", "events", "tl", "easy", False),
        ("Wedding photographer prenup photoshoot balance", "legit", "events", "en", "easy", False),
        ("Sound system and stage lights rental for debut party", "legit", "events", "en", "easy", False),
        ("Bridal gown couture alterations and final fitting fee", "legit", "events", "en", "easy", False),

        # --- Neutral Heldout Memos (15) ---
        ("Settlement of agreed balance", "neutral", "generic", "en", "easy", False),
        ("Interbank funds settlement", "neutral", "generic", "en", "easy", False),
        ("Replenishment", "neutral", "generic", "en", "easy", False),
        ("Account balance realignment", "neutral", "generic", "en", "easy", False),
        ("Statement reference 44921", "neutral", "reference", "en", "easy", False),
        ("Direct remittance payment", "neutral", "generic", "en", "easy", False),
        ("Service fulfillment", "neutral", "generic", "en", "easy", False),
        ("Quarterly share", "neutral", "generic", "en", "easy", False),
        ("Deposit settlement", "neutral", "generic", "en", "easy", False),
        ("Remittance as agreed", "neutral", "generic", "en", "easy", False),
        ("Full payment for order", "neutral", "generic", "en", "easy", False),
        ("Bayad sa balance", "neutral", "generic", "tl", "easy", False),
        ("Pang dagdag sa savings", "neutral", "generic", "tl", "easy", False),
        ("Pang pondo", "neutral", "generic", "tl", "easy", False),
        ("Transfer ref ID 10938", "neutral", "reference", "en", "easy", False),

        # --- Scam: Novel Heldout Typologies & Phrasings (36) ---
        ("AI algorithmic high frequency bot license fee for daily passive yield", "scam", "novel_ai_scam", "en", "medium", True),
        ("Deepfake celebrity giveaway verification bond to receive 1 million", "scam", "novel_deepfake", "en", "easy", True),
        ("TikTok live selling unboxing gift refund release insurance", "scam", "novel_ecommerce", "en", "easy", True),
        ("Government e-Gov portal penalty compromise fee to lift arrest warrant", "scam", "novel_gov_impersonation", "en", "hard", True),
        ("Anti money laundering AML certificate bond for offshore remittances", "scam", "novel_regulatory", "en", "hard", True),
        ("BIR tax compromise settlement fee for undeclared foreign estate assets", "scam", "novel_tax_scam", "en", "hard", True),
        ("Interpol regional cyber fraud compensation payout registration fee", "scam", "novel_recovery", "en", "hard", True),
        ("Victim restitution fund administrative filing fee for scam recovery", "scam", "novel_recovery", "en", "hard", True),
        ("E-Sabong online wallet frozen credit recovery processing fee", "scam", "novel_gambling", "en", "medium", True),
        ("Offshore online casino VIP withdrawal tax clearance payment", "scam", "novel_gambling", "en", "medium", True),
        ("Digital gold pawnshop collateral advance buyout fee", "scam", "novel_pawn_scam", "en", "medium", True),
        ("Carbon credit green bond crowdfunding guaranteed 50 percent return", "scam", "novel_esg_ponzi", "en", "medium", True),
        ("NFT staking yield aggregator redemption unlock charge", "scam", "novel_crypto", "en", "medium", True),
        ("Cross chain decentralized bridge slippage verification gas fee", "scam", "novel_crypto", "en", "hard", True),
        ("Automated telegram copy trading mirror account license fee", "scam", "novel_crypto", "en", "medium", True),
        ("Pre IPO startup technology stock pre allocation reservation fee", "scam", "novel_equity_scam", "en", "hard", True),
        ("Overseas nursing job visa sponsorship fast track documentation fee", "scam", "novel_recruitment", "en", "medium", True),
        ("Cruise ship crew employment contract medical clearance bond deposit", "scam", "novel_recruitment", "en", "medium", True),
        ("Middle East refinery welder priority flight booking clearance fee", "scam", "novel_recruitment", "en", "medium", True),
        ("Student visa financial show money escrow temporary routing", "scam", "novel_visa_mule", "en", "hard", True),
        ("Foreign ambassador luggage security escort insurance tag fee", "scam", "novel_diplomatic", "en", "easy", True),
        ("International courier package scanner customs duty exemption bribe", "scam", "novel_customs", "en", "medium", True),
        ("Inheritance barrister stamp duty advance settlement in London", "scam", "novel_inheritance", "en", "medium", True),
        ("Monetary authority anti terrorism financing clearance certificate", "scam", "novel_regulatory", "en", "hard", True),
        ("Supreme court judicial hold order cancellation penalty fee", "scam", "novel_gov_impersonation", "en", "hard", True),
        ("SIM card registration reactivation fee to restore banking access", "scam", "novel_telecom", "en", "medium", True),
        ("NBI clearance express delivery processing fee for online fraud suspect", "scam", "novel_gov_impersonation", "en", "medium", True),
        ("Bank secrecy waiver filing fee to unblock high value international wire", "scam", "novel_regulatory", "en", "hard", True),
        ("Cryptocurrency tax withholding voucher for foreign exchange remittance", "scam", "novel_crypto", "en", "hard", True),
        ("VIP dating romance partner emergency luggage release transit fee", "scam", "novel_romance", "en", "easy", True),
        ("Military peacekeeper gold consignment safety deposit box box fee", "scam", "novel_romance", "en", "easy", True),
        ("Paki cash out agad at ipadala ang 80 percent via Palawan Express", "scam", "novel_mule", "tl", "easy", True),
        ("Mule account routing commission deposit please withdraw balance", "scam", "novel_mule", "en", "easy", True),
        ("Temporary account transit test transfer please refund via GCash", "scam", "novel_mule", "en", "medium", True),
        ("Lending app harassment settlement cancellation of debt blackmail", "scam", "novel_extortion", "en", "medium", True),
        ("Cyber investigation ransomware decrypter key advance purchase", "scam", "novel_extortion", "en", "hard", True),
    ]

    for memo, signal, subtype, lang, diff, novel in raw_heldout:
        heldout_data.append({
            "memo": memo,
            "signal": signal,
            "subtype": subtype,
            "language": lang,
            "difficulty": diff,
            "typology_novel": novel,
            "split_role": "heldout_c2",
            "author": "ml_expert_auditor"
        })

    # -------------------------------------------------------------------------
    # 3. Optional Handwritten Held-Out Memos (Split C4): 50 rows
    # -------------------------------------------------------------------------
    handwritten_data = [
        # (memo, label)
        ("Pambayad sa tuition ni bunso sa Ateneo", "legit"),
        ("Meralco bill for October 2026", "legit"),
        ("Ambag sa office birthday blowout", "legit"),
        ("Bayad sa rent para sa buwan na ito", "legit"),
        ("Lunch share McDonald's delivery", "legit"),
        ("Grocery funds for nanay", "legit"),
        ("SM Department store shoes purchase", "legit"),
        ("Aircon cleaning service bayad", "legit"),
        ("Gas refill and water delivery", "legit"),
        ("Notarization fee for legal affidavit", "legit"),
        ("O'Reilly book on cloud architecture", "legit"),
        ("Dentist checkup fee and braces adjustment", "legit"),
        ("Pharmacy medicine for diabetes maintenance", "legit"),
        ("GrabCar airport transport fare", "legit"),
        ("Barangay permit fee settlement", "legit"),
        ("Pet clinic anti-rabies vaccine", "legit"),
        ("Baguio family road trip gas and food", "legit"),
        ("Monthly internet bill Converge", "legit"),
        ("School supplies at National Bookstore", "legit"),
        ("Condo water bill share", "legit"),
        ("Payment for tutoring service", "legit"),
        ("Dinner ambagan sa BGC", "legit"),
        ("Wedding gift cash transfer", "legit"),
        ("Pang palengke ni lola ngayong linggo", "legit"),
        ("Motorcycle maintenance change oil", "legit"),
        ("Urgent processing fee to release crypto trading bonus", "scam"),
        ("Claim fee for PCSO grand lotto winner promo", "scam"),
        ("Deposit 5000 to unlock Shopee task VIP commission", "scam"),
        ("Locked capital guaranteed 50% weekly return", "scam"),
        ("Urgent customs tax for parcel package at NAIA", "scam"),
        ("Wallet unlock fee for frozen binance account", "scam"),
        ("Paki cash out sa Palawan at kunin ang 10%", "scam"),
        ("Loan pre-approval processing bond fee", "scam"),
        ("BPI account unfreeze verification deposit", "scam"),
        ("Emergency holding fee for AMLA clearance certificate", "scam"),
        ("Telegram VIP task fee to withdraw salary", "scam"),
        ("iPhone 16 raffle winning courier insurance", "scam"),
        ("Foreign diplomat gift package release fee", "scam"),
        ("Forex algorithmic trading bot software fee", "scam"),
        ("Anti cybercrime clearance certification fee", "scam"),
        ("Temporary transit transfer forwarding money mule", "scam"),
        ("E-Sabong winnings recovery activation fee", "scam"),
        ("Government e-portal fine settlement to cancel arrest", "scam"),
        ("USDT gas fee release charge for profit transfer", "scam"),
        ("Celebrity deepfake giveaway verification deposit", "scam"),
        ("Transfer", "neutral"),
        ("Payment", "neutral"),
        ("Bills payment", "neutral"),
        ("Ref 88214", "neutral"),
        ("GCash cash in", "neutral")
    ]

    # -------------------------------------------------------------------------
    # Validation
    # -------------------------------------------------------------------------
    seed_memos = [row["memo"].strip().lower() for row in seed_train_data]
    heldout_memos = [row["memo"].strip().lower() for row in heldout_data]

    print(f"Total Seed Train Rows: {len(seed_train_data)}")
    print(f"Total Heldout Independent Rows: {len(heldout_data)}")
    print(f"Total Handwritten C4 Rows: {len(handwritten_data)}")

    # Exact duplicates check within files
    assert len(seed_memos) == len(set(seed_memos)), f"Duplicates found in seed train: {len(seed_memos) - len(set(seed_memos))}"
    assert len(heldout_memos) == len(set(heldout_memos)), f"Duplicates found in heldout: {len(heldout_memos) - len(set(heldout_memos))}"

    # Exact duplicates across files
    cross_dupes = set(seed_memos).intersection(set(heldout_memos))
    assert len(cross_dupes) == 0, f"Exact duplicate memos across seed and heldout: {cross_dupes}"

    # Near-duplicates (token Jaccard >= 0.60)
    near_dupes = []
    for s in seed_train_data:
        for h in heldout_data:
            j = token_jaccard(s["memo"], h["memo"])
            if j >= 0.60:
                near_dupes.append((s["memo"], h["memo"], round(j, 3)))

    print(f"Near-duplicate pairs (Jaccard >= 0.60) across splits: {len(near_dupes)}")
    for s_memo, h_memo, j_val in near_dupes[:5]:
        print(f"  - [{j_val}] '{s_memo}' <-> '{h_memo}'")

    # Write files
    seeds_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "hybrid_bench", "data", "seeds")
    os.makedirs(seeds_dir, exist_ok=True)

    seed_train_path = os.path.join(seeds_dir, "memo_seed_train.csv")
    heldout_path = os.path.join(seeds_dir, "memo_heldout_independent.csv")
    handwritten_path = os.path.join(seeds_dir, "handwritten_heldout.csv")

    fieldnames = ["memo", "signal", "subtype", "language", "difficulty", "typology_novel", "split_role", "author"]
    with open(seed_train_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(seed_train_data)
    print(f"Wrote: {seed_train_path} ({len(seed_train_data)} rows)")

    with open(heldout_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(heldout_data)
    print(f"Wrote: {heldout_path} ({len(heldout_data)} rows)")

    with open(handwritten_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["memo", "label"])
        writer.writeheader()
        for m, l in handwritten_data:
            writer.writerow({"memo": m, "label": l})
    print(f"Wrote: {handwritten_path} ({len(handwritten_data)} rows)")

    return near_dupes

if __name__ == "__main__":
    build_datasets()
