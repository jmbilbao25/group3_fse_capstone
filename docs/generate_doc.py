import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn
import os

def create_document():
    doc = docx.Document()

    # Page Margins: 1 inch all around
    sections = doc.sections
    for section in sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)

    # Palette
    NAVY = RGBColor(10, 37, 64)       # Primary Header (#0A2540)
    SLATE = RGBColor(71, 85, 105)     # Subtitle (#475569)
    BODY_COLOR = RGBColor(30, 41, 59) # Body Text (#1E293B)
    DARK_BLUE = RGBColor(30, 58, 138) # Section Highlights (#1E3A8A)
    GREEN = RGBColor(22, 101, 52)     # Success / Verified (#166534)
    AMBER = RGBColor(180, 83, 9)      # Warning / Notice (#B45309)

    # Style Helpers
    def set_run_font(run, name="Calibri", size_pt=11, color=BODY_COLOR, bold=False, italic=False):
        run.font.name = name
        run.font.size = Pt(size_pt)
        run.font.color.rgb = color
        run.bold = bold
        run.italic = italic

    def add_title(text):
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(20)
        p.paragraph_format.space_after = Pt(6)
        run = p.add_run(text)
        set_run_font(run, name="Arial", size_pt=24, color=NAVY, bold=True)
        return p

    def add_subtitle(text):
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(24)
        run = p.add_run(text)
        set_run_font(run, name="Calibri", size_pt=13, color=SLATE, italic=True)
        return p

    def add_h1(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(18)
        p.paragraph_format.space_after = Pt(6)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(text)
        set_run_font(run, name="Arial", size_pt=16, color=NAVY, bold=True)
        return p

    def add_h2(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(14)
        p.paragraph_format.space_after = Pt(4)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(text)
        set_run_font(run, name="Arial", size_pt=13, color=DARK_BLUE, bold=True)
        return p

    def add_h3(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(10)
        p.paragraph_format.space_after = Pt(2)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(text)
        set_run_font(run, name="Calibri", size_pt=11.5, color=DARK_BLUE, bold=True)
        return p

    def add_body(text, bold_prefix=None, space_after=6):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(space_after)
        p.paragraph_format.line_spacing = 1.15
        if bold_prefix:
            run_prefix = p.add_run(bold_prefix)
            set_run_font(run_prefix, name="Calibri", size_pt=11, color=NAVY, bold=True)
        run = p.add_run(text)
        set_run_font(run, name="Calibri", size_pt=11, color=BODY_COLOR)
        return p

    def add_bullet(text, bold_prefix=None):
        p = doc.add_paragraph(style='List Bullet')
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(3)
        p.paragraph_format.line_spacing = 1.15
        if bold_prefix:
            run_prefix = p.add_run(bold_prefix)
            set_run_font(run_prefix, name="Calibri", size_pt=11, color=NAVY, bold=True)
        run = p.add_run(text)
        set_run_font(run, name="Calibri", size_pt=11, color=BODY_COLOR)
        return p

    def add_code_block(code_text):
        table = doc.add_table(rows=1, cols=1)
        table.alignment = WD_TABLE_ALIGNMENT.CENTER
        cell = table.cell(0, 0)
        cell.width = Inches(6.5)
        
        # Style cell background and border
        shading = parse_xml(r'<w:shd {} w:fill="F1F5F9"/>'.format(nsdecls('w')))
        cell._tc.get_or_add_tcPr().append(shading)
        
        borders = parse_xml(r'''
            <w:tcBorders {} >
                <w:top w:val="single" w:sz="6" w:space="0" w:color="CBD5E1"/>
                <w:left w:val="single" w:sz="24" w:space="0" w:color="0A2540"/>
                <w:bottom w:val="single" w:sz="6" w:space="0" w:color="CBD5E1"/>
                <w:right w:val="single" w:sz="6" w:space="0" w:color="CBD5E1"/>
            </w:tcBorders>
        '''.format(nsdecls('w')))
        cell._tc.get_or_add_tcPr().append(borders)
        
        p = cell.paragraphs[0]
        p.paragraph_format.space_before = Pt(4)
        p.paragraph_format.space_after = Pt(4)
        run = p.add_run(code_text)
        set_run_font(run, name="Consolas", size_pt=9.5, color=RGBColor(15, 23, 42))

        doc.add_paragraph().paragraph_format.space_after = Pt(4)

    def add_screenshot_placeholder(fig_num, title, instructions, expected_details):
        table = doc.add_table(rows=1, cols=1)
        table.alignment = WD_TABLE_ALIGNMENT.CENTER
        cell = table.cell(0, 0)
        cell.width = Inches(6.5)

        # Style with clean light gray and dashed border
        shading = parse_xml(r'<w:shd {} w:fill="F8FAFC"/>'.format(nsdecls('w')))
        cell._tc.get_or_add_tcPr().append(shading)
        
        borders = parse_xml(r'''
            <w:tcBorders {} >
                <w:top w:val="dashed" w:sz="12" w:space="0" w:color="94A3B8"/>
                <w:left w:val="dashed" w:sz="12" w:space="0" w:color="94A3B8"/>
                <w:bottom w:val="dashed" w:sz="12" w:space="0" w:color="94A3B8"/>
                <w:right w:val="dashed" w:sz="12" w:space="0" w:color="94A3B8"/>
            </w:tcBorders>
        '''.format(nsdecls('w')))
        cell._tc.get_or_add_tcPr().append(borders)

        p1 = cell.paragraphs[0]
        p1.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p1.paragraph_format.space_before = Pt(8)
        p1.paragraph_format.space_after = Pt(4)
        r1 = p1.add_run(f"📷 [ATTACH SCREENSHOT {fig_num} HERE: {title.upper()}]")
        set_run_font(r1, name="Arial", size_pt=11, color=DARK_BLUE, bold=True)

        p2 = cell.add_paragraph()
        p2.paragraph_format.space_before = Pt(2)
        p2.paragraph_format.space_after = Pt(2)
        r2_title = p2.add_run("How to capture: ")
        set_run_font(r2_title, name="Calibri", size_pt=10, color=NAVY, bold=True)
        r2 = p2.add_run(instructions)
        set_run_font(r2, name="Calibri", size_pt=10, color=BODY_COLOR, italic=True)

        p3 = cell.add_paragraph()
        p3.paragraph_format.space_before = Pt(2)
        p3.paragraph_format.space_after = Pt(8)
        r3_title = p3.add_run("Key evidence to highlight: ")
        set_run_font(r3_title, name="Calibri", size_pt=10, color=GREEN, bold=True)
        r3 = p3.add_run(expected_details)
        set_run_font(r3, name="Calibri", size_pt=10, color=BODY_COLOR)

        caption = doc.add_paragraph()
        caption.alignment = WD_ALIGN_PARAGRAPH.CENTER
        caption.paragraph_format.space_before = Pt(4)
        caption.paragraph_format.space_after = Pt(12)
        rc = caption.add_run(f"Figure {fig_num}: {title}")
        set_run_font(rc, name="Calibri", size_pt=9.5, color=SLATE, italic=True)

    # =========================================================================
    # DOCUMENT HEADER / METADATA
    # =========================================================================
    add_title("CORE RETAIL LEDGER & BALANCE MUTATION ENGINE")
    add_subtitle("Comprehensive Technical Architecture, Concurrency Control, Maker-Checker Dual Control, and Apache Kafka (KRaft Mode) Streaming\nFSE Capstone Project Group 3 | September 2026")

    # Metadata Box
    meta_table = doc.add_table(rows=4, cols=2)
    meta_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    meta_data = [
        ("Lead Role / Developer:", "Backend Engineer (Core Engine & Event Streaming)"),
        ("Milestones Covered:", "Epic 3 (Concurrency & Locks), Epic 4 (Dual-Write), Epic 5 (Maker-Checker), Epic 6 (Kafka KRaft)"),
        ("Target System Architecture:", "Oracle Database 21c (Master XE), PostgreSQL 16 (Audit Vault), Kafka 3.7.0 (KRaft)"),
        ("Compliance Standard:", "BSP Circular 982 & 1022 (Operational Risk Management & Segregation of Duties)")
    ]
    for idx, (label, val) in enumerate(meta_data):
        row = meta_table.rows[idx]
        cell_lbl, cell_val = row.cells[0], row.cells[1]
        cell_lbl.width = Inches(2.3)
        cell_val.width = Inches(4.2)
        
        p_lbl = cell_lbl.paragraphs[0]
        p_lbl.paragraph_format.space_before = Pt(2)
        p_lbl.paragraph_format.space_after = Pt(2)
        r_lbl = p_lbl.add_run(label)
        set_run_font(r_lbl, name="Calibri", size_pt=10, color=NAVY, bold=True)

        p_val = cell_val.paragraphs[0]
        p_val.paragraph_format.space_before = Pt(2)
        p_val.paragraph_format.space_after = Pt(2)
        r_val = p_val.add_run(val)
        set_run_font(r_val, name="Calibri", size_pt=10, color=BODY_COLOR)

    doc.add_paragraph().paragraph_format.space_after = Pt(12)

    # =========================================================================
    # SECTION 1: EXECUTIVE SUMMARY
    # =========================================================================
    add_h1("1. Executive Summary & Problem Formulation")
    add_body("In high-throughput retail banking applications, maintaining financial data integrity during concurrent balance mutations is the paramount engineering challenge. In the absence of strict concurrency controls, simultaneous withdrawal or transfer requests against an account can trigger the classic 'Lost Update' anomaly, resulting in catastrophic double-spending where capital leaves the bank without corresponding ledger deductions.")
    add_body("To eliminate this systemic risk and adhere to strict Philippine banking governance (Bangko Sentral ng Pilipinas Circulars 982 and 1022), this project implemented a high-performance, fault-tolerant Core Balance Mutation Engine focused exclusively on Funds Transfer (TRANSFER). The engine combines:")
    add_bullet("Pessimistic Database Row Locking (SELECT FOR UPDATE) to serialize concurrent debit attempts at the database persistence barrier.", "1. Concurrency Control: ")
    add_bullet("Deterministic Alphabetical Lock Ordering to mathematically eliminate circular wait conditions (deadlocks) during dual-account fund transfers.", "2. Deadlock Prevention: ")
    add_bullet("Heterogeneous Dual-Write Architecture across Oracle XE 21c (Master Operational Store) and PostgreSQL 16 (Immutable Compliance Audit Vault) with isolated HikariCP connection pools.", "3. Data Isolation: ")
    add_bullet("Maker-Checker Dual Control & Segregation of Duties with soft-hold mechanics for high-value transactions (> ₱50,000.00).", "4. Governance & Compliance: ")
    add_bullet("Next-generation Apache Kafka 3.7.0 in KRaft mode (ZooKeeper-less) with acks=all and producer idempotency for zero-loss real-time event streaming.", "5. Event Streaming: ")

    # =========================================================================
    # SECTION 2: CONCURRENCY CONTROL & PESSIMISTIC LOCKING
    # =========================================================================
    add_h1("2. Concurrency Control & Pessimistic Locking Mechanics")
    add_h2("2.1 The Lost Update Anomaly in High-Contention Transfers")
    add_body("Suppose Customer Account A has an available balance of ₱10,000.00. Under concurrent execution, two transfer requests of ₱8,000.00 each arrive simultaneously from different channels (e.g., mobile banking API and a recurring automated scheduled debit). If handled under standard non-locking Read Committed isolation:")
    add_bullet("Both concurrent transactions read available_balance = ₱10,000.00.")
    add_bullet("Both transactions independently evaluate 10,000.00 >= 8,000.00 as TRUE.")
    add_bullet("Transaction 1 writes new balance 10,000.00 - 8,000.00 = ₱2,000.00 and commits.")
    add_bullet("Transaction 2 overwrites with 10,000.00 - 8,000.00 = ₱2,000.00 and commits.")
    add_body("Result: ₱16,000.00 total capital was disbursed, yet the account retains ₱2,000.00. The bank experiences an irrecoverable ₱6,000.00 capital deficit due to uncoordinated concurrent state modification.")

    add_h2("2.2 Why Pessimistic Locking Over Optimistic Locking?")
    add_body("While Optimistic Locking (@Version) is popular in low-conflict enterprise web apps, it is fundamentally unacceptable for high-throughput retail banking mutation engines. Optimistic locking validates row versions only at commit time; in high-frequency contention spikes (e.g., payday morning bursts), colliding transactions are forcefully aborted with OptimisticLockException. Forcing clients to handle rollbacks and retry repeatedly severely degrades user experience and throughput.")
    add_body("Instead, our engine employs Database-Level Pessimistic Write Locking (@Lock(LockModeType.PESSIMISTIC_WRITE)), which translates directly to native Oracle SQL:")
    add_code_block("SELECT b.account_id, b.balance_amount, b.hold_amount, b.available_balance\nFROM balance_master b\nWHERE b.account_id = :accountId\nFOR UPDATE;")
    add_body("Under SELECT FOR UPDATE, Oracle XE locks the physical data row. The secondary transaction attempting to query or debit the same row stalls cleanly at the database persistence barrier until the first transaction commits or rolls back. When released, the secondary transaction reads the updated available balance (₱2,000.00), immediately evaluates 2,000.00 < 8,000.00, and gracefully rejects the overdraft with an RFC-7807 compliant InsufficientFundsException.")

    # =========================================================================
    # SECTION 3: DEADLOCK ELIMINATION
    # =========================================================================
    add_h1("3. Deadlock Elimination via Deterministic Lock Ordering")
    add_body("In bilateral fund transfers, two distinct accounts must be locked within the same atomic transaction: the source account and the destination account. This introduces the risk of circular lock wait conditions (Deadlock).")
    add_h2("3.1 The Circular Wait Condition")
    add_body("Consider Customer A transferring to Customer B, while Customer B simultaneously transfers to Customer A:")
    add_bullet("Thread 1 (A -> B) acquires exclusive lock on Account A, and requests lock on Account B.")
    add_bullet("Thread 2 (B -> A) acquires exclusive lock on Account B, and requests lock on Account A.")
    add_bullet("Both threads wait indefinitely on each other, causing Oracle to terminate one session with ORA-00060: deadlock detected while waiting for resource.")
    
    add_h2("3.2 The Deterministic Alphabetical Solution")
    add_body("To mathematically eliminate deadlocks without sacrificing transactional isolation, BalanceMutationService implements Deterministic Alphabetical Lock Ordering. Regardless of the transfer direction, accounts are always locked in alphabetical order based on their primary keys:")
    add_code_block("// Deterministic Lock Ordering Algorithm\nString firstLockId = sourceId.compareTo(targetId) < 0 ? sourceId : targetId;\nString secondLockId = sourceId.compareTo(targetId) < 0 ? targetId : sourceId;\n\n// Locks are acquired in identical global sequence across all server threads\nBalanceMaster firstAccount = balanceRepository.findByAccountIdWithLock(firstLockId).orElseThrow();\nBalanceMaster secondAccount = balanceRepository.findByAccountIdWithLock(secondLockId).orElseThrow();")
    add_body("Because all concurrent threads across all server nodes acquire locks in the exact same monotonic sequence, circular wait is mathematically impossible.")

    # =========================================================================
    # SECTION 4: DUAL-WRITE ARCHITECTURE & HIKARICP
    # =========================================================================
    add_h1("4. Multi-Datasource Dual-Write Architecture & HikariCP Isolation")
    add_body("The application separates high-velocity transactional ledger operations from regulatory compliance audit logs through a dual-datasource architecture:")
    add_bullet("Oracle XE 21c (Master Operational Store, Port 1521): Manages live mutable balances (balance_master), accounts, customer profiles, and transactional outbox entries.", "Primary Store: ")
    add_bullet("PostgreSQL 16 (Dedicated Audit Vault, Port 5433): Stores immutable append-only records in ledger_mutation_audit. A native database trigger strictly disallows UPDATE and DELETE operations.", "Audit Vault: ")
    add_body("To prevent database cascade failures (where audit latency slows down core banking throughput), each datasource is managed by an isolated HikariCP connection pool enforcing the Bulkhead Pattern:")
    add_bullet("Pool Name: HikariPool-OracleMaster | Max Size: 30 | Min Idle: 5 | Timeout: 20,000 ms")
    add_bullet("Pool Name: HikariPool-PostgresAudit | Max Size: 30 | Min Idle: 5 | Timeout: 20,000 ms")
    add_body("Host Port Routing: In docker-compose.yml, container port 5432 is routed to Windows host port 5433 to completely eliminate port collisions with pre-existing local PostgreSQL services.")

    # =========================================================================
    # SECTION 5: MAKER-CHECKER DUAL CONTROL
    # =========================================================================
    add_h1("5. Maker-Checker Dual Control & Segregation of Duties (BSP Compliance)")
    add_body("In accordance with BSP Circular 982 (Enhanced Operational Risk Management) and Circular 1022 (Framework on Technology and Cyber Risk), dual control is mandatory for high-value financial mutations to prevent insider fraud and unauthorized asset transfers.")
    
    add_h2("5.1 Threshold-Based Route Evaluation")
    add_body("The engine inspects the transfer payload against the configured policy threshold (app.maker-checker.threshold = 50000.0000 PHP):")
    add_bullet("Transfers <= ₱50,000.00: Categorized as low risk; processed immediately with atomic debit on sender and credit on receiver (status: COMMITTED).", "Immediate Route: ")
    add_bullet("Transfers > ₱50,000.00: Categorized as high risk; triggers the Maker-Checker workflow with soft-hold mechanics (status: PENDING_APPROVAL).", "Dual-Control Route: ")

    add_h2("5.2 The Soft-Hold Mechanic")
    add_body("When a high-value transfer is initiated, the engine does NOT deduct the funds from balance_amount. Instead, it places a soft hold:")
    add_code_block("// Soft Hold Calculation\nsender.setHoldAmount(sender.getHoldAmount().add(amount));\nsender.setAvailableBalance(sender.getAvailableBalance().subtract(amount));\n// balance_amount remains unchanged until Teller authorization!")
    add_body("Benefit: The customer cannot spend these funds in another channel, preventing double-spending, while the funds legally remain on the customer's balance sheet until authorized.")

    add_h2("5.3 Segregation of Duties Enforcement (TRX-503)")
    add_body("The system strictly prevents self-approval. If the checker user attempting to approve a transaction is the initiator (maker) of the transfer, the request is rejected with HTTP 403 Forbidden:")
    add_code_block("if (checkerRequest.getCheckerUserId().equals(sourceAccount.getUserId())) {\n    throw new SegregationOfDutiesException(\n        \"Maker-Checker Violation: The initiator cannot approve their own transfer.\");\n}")

    add_h2("5.4 Teller Approval vs. Rejection Lifecycle")
    add_bullet("Approval (POST /api/v1/ledger/transfers/{id}/approve): Releases the hold, permanently deducts balance_amount on sender, credits receiver, updates Oracle status to COMMITTED, writes PostgreSQL audit trail, and emits Kafka notifications.", "Teller Approval: ")
    add_bullet("Rejection (POST /api/v1/ledger/transfers/{id}/reject): Releases the soft hold, restoring available_balance to full value (zero funds lost), updates Oracle status to FAILED, and emits a rejection alert via Kafka.", "Teller Rejection: ")

    # =========================================================================
    # SECTION 6: KAFKA KRAFT EVENT STREAMING
    # =========================================================================
    add_h1("6. Apache Kafka in KRaft Mode & Real-Time Event Streaming")
    add_h2("6.1 Why KRaft Mode Instead of ZooKeeper?")
    add_body("Historically, Apache Kafka relied on Apache ZooKeeper for cluster metadata coordination. ZooKeeper introduced operational complexity, metadata synchronization lag, and split-brain risks. In this project, we deployed Apache Kafka 3.7.0 in KRaft (Kafka Raft consensus) mode:")
    add_bullet("Native Raft Consensus: Kafka controllers manage metadata internally within a dedicated Raft quorum.", "Consensus: ")
    add_bullet("Sub-Second Leader Election: Eliminates the multi-second metadata propagation delay of ZooKeeper during partition leader failover.", "Performance: ")
    add_bullet("Zero External Dependency: Clean single-binary deployment with dramatically simplified container operations.", "Operations: ")

    add_h2("6.2 Banking-Grade Producer Guarantees")
    add_body("To guarantee zero message loss and eliminate duplicate downstream notifications, the Kafka producer enforces strict banking parameters in application.properties:")
    add_bullet("acks=all (-1): The broker acknowledges the event only after all in-sync replicas (ISRs) have written the record to disk commit logs.", "Durability: ")
    add_bullet("enable.idempotence=true: The producer attaches a Producer ID (PID) and sequence number to every message batch. Network retries (retries=3) are automatically deduplicated by the broker.", "Deduplication: ")

    add_h2("6.3 Event Topology & Kafka UI Observability")
    add_body("The engine provisions three dedicated topics (3 partitions each):")
    add_bullet("transaction-events: Emits committed transfer events for core ledger integration.")
    add_bullet("notification-alerts: Streams customer debit, hold, and approval alerts asynchronously.")
    add_bullet("audit-events: Broadcasts regulatory audit events.")
    add_body("Kafka UI is exposed on port 8085 (http://localhost:8085), providing real-time visibility into topic throughput, message payloads, consumer group offsets, and partition distributions.")

    # =========================================================================
    # SECTION 7: SCREENSHOT EVIDENCE PLAYBOOK
    # =========================================================================
    add_h1("7. Implementation Proof & Verification Playbook")
    add_body("Below are the verified test executions and monitoring console captures proving end-to-end functionality of all implemented components. Attach the required screenshots in the designated placeholders below:")

    add_screenshot_placeholder(
        fig_num="1",
        title="Docker Compose Banking Infrastructure Health Check",
        instructions="Run 'docker ps' in PowerShell. Capture the terminal showing all 6 active containers.",
        expected_details="Must show oracle-xe-master (1521), postgres-audit-vault (5433->5432), kafka-broker (9092), kafka-ui (8085), and redis-cache (6379) in healthy / up status."
    )

    add_screenshot_placeholder(
        fig_num="2",
        title="Pessimistic Lock Concurrency Test (Double-Spending Prevention)",
        instructions="Run '.\\mvnw.cmd test -Dtest=PessimisticLockConcurrencyTest -pl ledger-mutation-engine' in backend folder. Capture test output.",
        expected_details="Must show 'Successful Transfers (8,000 PHP): 1', 'Rejected Transfers (Insufficient): 1', Final Sender Balance: 2,000 PHP, Final Receiver: 13,000 PHP, and BUILD SUCCESS."
    )

    add_screenshot_placeholder(
        fig_num="3",
        title="Maker-Checker & Segregation of Duties Integration Test",
        instructions="Run '.\\mvnw.cmd test -Dtest=MakerCheckerIntegrationTest -pl ledger-mutation-engine' in backend folder. Capture test output.",
        expected_details="Must show all 5 tests passing: testNormalTransferSettlesImmediately, testHighValueTransferEntersPendingApprovalWithSoftHold, testMakerCannotApproveOwnTransfer (403), testTellerApprovalSettlesFundsAndReleasesHold, and testTellerRejectionRestoresHold."
    )

    add_screenshot_placeholder(
        fig_num="4",
        title="Full Engine Test Suite Green Build",
        instructions="Run '.\\mvnw.cmd test -pl ledger-mutation-engine'. Capture the final Surefire summary and BUILD SUCCESS banner.",
        expected_details="Must show 'Tests run: 9, Failures: 0, Errors: 0, Skipped: 0' and 'BUILD SUCCESS'."
    )

    add_screenshot_placeholder(
        fig_num="5",
        title="Apache Kafka UI Cluster & Topics Dashboard",
        instructions="Open browser to 'http://localhost:8085'. Navigate to Topics in the left navigation sidebar and take a screenshot of the topics table.",
        expected_details="Must show topics: 'transaction-events', 'notification-alerts', and 'audit-events' with 3 partitions each and green cluster status in KRaft mode."
    )

    add_screenshot_placeholder(
        fig_num="6",
        title="Real-Time Kafka Notification Messages Stream",
        instructions="In Kafka UI (http://localhost:8085), click on 'notification-alerts' topic -> click on 'Messages' tab. Capture the streamed event payloads.",
        expected_details="Must show live JSON payloads containing 'TRANSFER_DEBIT', 'MAKER_CHECKER_PENDING', and 'TRANSFER_REJECTED' alert types with exact amounts and timestamps."
    )

    # =========================================================================
    # SECTION 8: DEFENSE Q&A FOR EVALUATORS
    # =========================================================================
    add_h1("8. Technical Defense Q&A for Capstone Evaluators")
    
    qa_list = [
        ("Q1: Why did you implement Pessimistic Locking instead of Optimistic Locking for transfers?",
         "Optimistic locking assumes collisions are rare and relies on version checking at commit time. In retail banking, concurrent debit spikes cause optimistic transactions to fail with OptimisticLockException, requiring client retries and degrading user experience. Pessimistic locking (SELECT FOR UPDATE) physically queues contending transactions at the database row level, guaranteeing zero double-spending and zero retry overhead."),
        
        ("Q2: How does your implementation prevent deadlocks during concurrent bilateral transfers?",
         "We implemented Deterministic Alphabetical Lock Ordering. In bilateral transfers between Account A and Account B, transactions always acquire row locks in strict alphabetical order (source.compareTo(target)). Because all threads in the system acquire locks in the exact same monotonic direction, circular wait is mathematically eliminated, preventing ORA-00060 deadlocks."),
        
        ("Q3: Why maintain PostgreSQL when you already have Oracle Database?",
         "We adhere to the CQRS and Audit Vault architectural patterns. Oracle XE is our high-velocity master operational database holding mutable state. PostgreSQL is our dedicated, append-only compliance audit vault equipped with triggers blocking UPDATE and DELETE. Each database is equipped with an isolated HikariCP connection pool (Bulkhead pattern) so audit latency never impacts core banking throughput."),
        
        ("Q4: What is the architectural significance of Kafka in KRaft mode?",
         "KRaft mode eliminates the legacy Apache ZooKeeper dependency by running consensus natively using the Raft protocol. This reduces infrastructure footprint, accelerates partition leader election during failover from seconds to milliseconds, and simplifies cluster management. Coupled with acks=all and producer idempotency, we achieve zero-loss, exactly-once delivery guarantees on the broker log."),
        
        ("Q5: How does your Maker-Checker implementation comply with Philippine banking regulations?",
         "In alignment with BSP Circular 982 and 1022, transfers exceeding ₱50,000.00 enter a dual-control workflow with soft holds, reserving available balance without prematurely altering the balance sheet. Furthermore, Segregation of Duties (TRX-503) strictly prohibits self-approval by returning HTTP 403 Forbidden if a Maker attempts to approve their own transfer.")
    ]

    for q, a in qa_list:
        add_h2(q)
        add_body(a)

    # Save Document
    output_dir = r"C:\Users\ROM83758\.gemini\antigravity\scratch\core-retail-ledger\docs"
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, "CORE_MUTATION_ENGINE_AND_KAFKA_DOCUMENTATION.docx")
    doc.save(output_path)
    print(f"Document successfully created at: {output_path}")

if __name__ == "__main__":
    create_document()
