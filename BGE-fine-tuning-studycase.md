# Fine-tuning BGE-M3 for Saudi legal data setup

**Session ID:** ses_2bfa0fbf1ffe0YQuQiAdrHLunC
**Created:** 3/30/2026, 11:11:02 PM
**Updated:** 3/31/2026, 12:24:22 AM

---

## User

in @plans/ai-improvement-phase2-reranking-embeddings.md it mentioned fine-tuning, and i'm not an ML enigneer so i don't know how to fine tuning and what required, i have an RTX 4070 ti super so it good for ML i think, so what do i need and how can i fine tune our model

---

## Assistant (Build · claude-opus-4.6 · 1.4s)

---

## User

in @plans/ai-improvement-phase2-reranking-embeddings.md it mentioned fine-tuning, and i'm not an ML enigneer so i don't know how to fine tuning and what required, i have an RTX 4070 ti super so it good for ML i think, so what do i need and how can i fine tune our model

---

## Assistant (Build · gpt-5.3-codex · 26.2s)

_Thinking:_



Yes — your **RTX 4070 Ti Super (16GB VRAM)** is good enough to fine-tune an embedding model like BGE-M3 for your use case.

What you need is mostly **good training pairs**, not deep ML expertise.

**What You Need**
- Labeled data: `(case_text, regulation_text, relevant)` from your verified lawyer links.
- Enough positives: target `500+` positive pairs (more is better).
- Negatives: especially **hard negatives** (similar-but-wrong regulations).
- Python training stack: `torch`, `transformers`, `sentence-transformers`, `datasets`, `accelerate`.
- Evaluation set: hold out ~15–20% by `case_id` (not random rows) to avoid leakage.

**Recommended Training Setup (for your GPU)**
- Model: `BAAI/bge-m3`
- Loss: `MultipleNegativesRankingLoss`
- Max sequence length: `384` or `512`
- Batch size: start `8` (increase if no OOM)
- Epochs: `2–4`
- Learning rate: `2e-5`
- Mixed precision: `fp16=True`
- Warmup: `10%`

**Concrete Workflow for Your Plan**
1. Create `ai_service/scripts/export_training_data.py`
   - Export verified links from DB.
   - Build JSONL triplets like:
     - `{"query": "...case...", "positive": "...correct regulation...", "negative": "...hard negative..."}`
2. Generate hard negatives
   - For each case, retrieve top-k regulations with current BGE-M3.
   - Remove true linked regulation.
   - Prefer regulations that lawyers rejected (best hard negatives).
3. Fine-tune in `ai_service/scripts/fine_tune_bge.py`
   - Load triplets.
   - Train `SentenceTransformer("BAAI/bge-m3")` with MNRL.
   - Save to `models/bge-m3-saudi-legal-v1/`.
4. Evaluate before/after
   - Metrics: `Recall@10`, `MRR`, `nDCG@10`.
   - Only promote model if it beats baseline on held-out set.
5. Deploy
   - Add model path in `ai_service/app/config.py`.
   - Update `ai_service/app/core/embeddings.py` to load fine-tuned path with base-model fallback.

**Important Practical Tips**
- Keep Arabic text normalization consistent in train + inference.
- Deduplicate near-identical case/regulation texts before training.
- Do not train on records from evaluation cases.
- If OOM: lower batch size, lower max length, use gradient accumulation.

**Rough Time/Cost**
- Dataset prep: 1–2 days (usually longest part).
- First training run on 4070 Ti Super: a few hours depending on data size.
- Iteration cycle (train + eval): same day.

If you want, I can now draft both scripts (`export_training_data.py` and `fine_tune_bge.py`) directly in your repo with sane defaults for your GPU and your Phase 2 plan.

---

## User

what do i need to do? how the data should shape? is it ok to train on docs files? is the fine tuning only on code and data just that nothing else? briefly please

---

## Assistant (Build · gpt-5.3-codex · 11.9s)

_Thinking:_



Yes — briefly:

- You need 3 things: **(1) labeled pairs**, **(2) training script**, **(3) evaluation**.
- Data shape should be like this (JSONL is easiest):
```json
{"query":"<case text>", "positive":"<correct regulation text>", "negative":"<similar but wrong regulation text>"}
```
- Minimum useful size: ~`500+` positive pairs; better at `2k+`.

About training on docs files:
- **Usually no** for your goal.
- Best data is your **real verified case↔regulation links**.
- Raw docs can help only for domain pretraining, but for retrieval quality, labeled links matter much more.

Is fine-tuning only code + data?
- Mostly yes: script + dataset + GPU run.
- Also needed: **cleaning text**, **train/validation split**, **metric check (Recall@10/MRR)**, then **deploy model path** in app config.
- So it’s not just “run code once”; validation/deployment steps are important.

If you want, I can give you a 1-page exact checklist with commands for your 4070 Ti Super.

---

## User

what is the labeled pairs and can't we train on thisas example  because i don't think our data on our database is enough: https://open.data.gov.sa/ar/datasets/view/2eedb9dc-fb20-4650-a2bf-64af082327e2/api

---

## Assistant (Build · gpt-5.3-codex · 5.0s)

_Thinking:_



**Tool: webfetch**

**Input:**
```json
{
  "url": "https://open.data.gov.sa/ar/datasets/view/2eedb9dc-fb20-4650-a2bf-64af082327e2/api",
  "format": "markdown"
}
```

**Output:**
```
Platform | Open Data Platform
```

---

## Assistant (Build · gpt-5.3-codex · 7.5s)

_Thinking:_



**Tool: webfetch**

**Input:**
```json
{
  "url": "https://open.data.gov.sa/ar/datasets/view/2eedb9dc-fb20-4650-a2bf-64af082327e2",
  "format": "markdown"
}
```

**Output:**
```
Platform | Open Data Platform
```

---

## Assistant (Build · gpt-5.3-codex · 12.8s)

_Thinking:_



Great question.

- **Labeled pairs** means examples where you know the truth:
  - `query = case text`
  - `doc = regulation text`
  - `label = 1` (relevant) or `0` (not relevant)

- For BGE fine-tuning, best format is triplets:
```json
{"query":"case text","positive":"correct regulation","negative":"wrong but similar regulation"}
```

- About that open-data dataset link: **you can use it only if it contains usable text and license allows ML training**.
  - If it is just regulation documents (no case↔regulation links), it is **not enough alone** for supervised retrieval fine-tuning.
  - It can still help as **domain corpus** (legal Arabic language adaptation), but not as strong as real labeled links.

- If your DB labels are small, do hybrid:
  1. Use your verified links as gold labels.
  2. Add open legal docs as extra corpus.
  3. Create weak negatives/hard negatives from top-k retrieval.
  4. Fine-tune, then validate on a held-out gold set.

- So yes, training is mostly **data + code + GPU**, but quality depends mostly on **good labels** and **proper evaluation**.

If you want, I can give you a minimal “start with low data” recipe (exact files + commands) for your 4070 Ti Super.

---

## User

they gave me this as open-data data set: curl -X GET 'https://open.data.gov.sa/data/api/datasets?version=-1&dataset=2eedb9dc-fb20-4650-a2bf-64af082327e2' -H "Accept: application/json"
you can try it and this is example of expeted: {
    "transactionId": "String",
    "id": "String",
    "titleEn": "String",
    "titleAr": "String",
    "descriptionEn": "String",
    "descriptionAr": "String",
    "providerNameEn": "String",
    "providerNameAr": "String",
    "organizationId": "String",
    "updateFrequency": "String",
    "language": "String",
    "timePeriod": "String",
    "resourcesCount": "Integer",
    "categories": [
        {
            "id": "String",
            "nameEn": "String",
            "nameAr": "String",
            "titleEn": "String",
            "titleAr": "String",
            "descriptionEn": "String",
            "descriptionAr": "String"
        }
    ],
    "tags": [
        {
            "id": "String",
            "nameEn": "String",
            "nameAr": "String"
        }
    ],
    "createdAt": "String",
    "updatedAt": "String"
} 

---

## Assistant (Build · gpt-5.3-codex · 4.6s)

_Thinking:_



**Tool: bash**

**Input:**
```json
{
  "command": "curl -s -X GET \"https://open.data.gov.sa/data/api/datasets?version=-1&dataset=2eedb9dc-fb20-4650-a2bf-64af082327e2\" -H \"Accept: application/json\"",
  "description": "Fetch dataset metadata JSON from open data API"
}
```

**Output:**
```
{"transactionId":"80ed5ba5-81cc-4333-a456-2a5f21cc76b9","id":"2eedb9dc-fb20-4650-a2bf-64af082327e2","titleEn":"Total number of judicial decisions in courts of first instance in Jan 2026","titleAr":"القرارات الصادرة في محاكم الدرجة الأولى 2026 يناير","descriptionEn":"Total number of judicial decisions in cases reviewed by judges in courts of first instance in Jan 2026","descriptionAr":"القرارات القضائية الصادرة في القضايا المنظورة من قبل القضاة في محاكم الدرجة الأولى خلال شهر يناير في عام 2026","providerNameEn":"ministry of justice","providerNameAr":"وزارة العدل","organizationId":"35c63412-c4ae-4303-8fef-56cfd71303cf","updateFrequency":"MONTHLY","language":"Arabic","timePeriod":"2026-01-01 - 2026-01-31","resourcesCount":2,"categories":[{"id":"b8889c54-7ee9-425e-8dba-a244591e0335","titleEn":"Justice","titleAr":"العدل","descriptionEn":"Datasets within the legal and judicial dimension which could also include real-estate information","descriptionAr":"مجموعات البيانات ضمن البعد القانوني والقضائي والتي يمكن أن تتضمن معلومات عن العقارات"}],"tags":[{"id":"44adb5c1-3956-434e-b042-e96a3e795b5a","name":"القضايا"},{"id":"71a8f578-e09a-4deb-b9ed-b459ff52b7e9","name":"القرارات"},{"id":"8fb79cf7-bebe-41b5-ada7-abe4b056804b","name":"الأحكام"},{"id":"fad299f7-000e-4b98-a53a-ceafe63bd13e","name":"courts"},{"id":"e3107a7f-71e4-4030-a8be-49efb664a263","name":"cases"},{"id":"0d806804-efc1-4d94-a5ae-623efbcf61ce","name":"decisions"}],"createdAt":"2026-03-08 16:29:21","updatedAt":"2026-03-09 11:15:17"}
```

---

## Assistant (Build · gpt-5.3-codex · 5.5s)

Perfect, I tested your API link.

This dataset is **metadata/statistics about counts of court decisions** (Jan 2026), not full legal text pairs.  
So for your embedding fine-tuning goal:

- It is **not enough** for supervised retrieval fine-tuning.
- It does **not provide labeled pair structure** like `case -> correct regulation`.

What labeled data should look like:
- Binary pairs:
```json
{"query":"case text","doc":"regulation text","label":1}
{"query":"case text","doc":"another regulation","label":0}
```
- Or better triplets:
```json
{"query":"case text","positive":"correct regulation","negative":"similar but wrong regulation"}
```

What you should do now:
- Use your internal verified links as gold data (even if small).
- Add weak negatives from retrieval top-k.
- If data is small, start with **reranker first** (usually gives bigger gain with less data), then fine-tune embeddings.

So short answer: **this open dataset is useful context, but not training labels for your task**.

---

## User

you can see the data here @data/Jud Decisions CSV.csv is it suitable for training?

---

## Assistant (Build · gpt-5.3-codex · 6.9s)

_Thinking:_



Short answer: **not suitable for your main fine-tuning objective**.

- `data/Jud Decisions CSV.csv` has columns like region/city/case type/date/reference number, but **no case text** and **no linked regulation text**.
- For your retrieval model (case -> relevant regulation), you need labeled examples like:
  - `query = case narrative text`
  - `positive = correct regulation/article text`
  - `negative = wrong but similar regulation text`

So this CSV can be used only as **auxiliary metadata** (analytics, maybe filtering), not as core training data for embedding fine-tuning.

If your DB is small, best path is:
1. Start with available verified links (even small).  
2. Add hard negatives from retrieval.  
3. Use reranker first (often bigger gain with less data).

---

## User

ok and this one @data/Resolved Cases or Signed Memorandums1.csv 

---

## Assistant (Build · gpt-5.3-codex · 5.4s)

_Thinking:_



Also **not suitable** for fine-tuning.

- `data/Resolved Cases or Signed Memorandums1.csv` is only aggregated stats (year, case type, court type, percentage).
- It has no legal text and no case↔regulation relevance labels.
- Only 3 data rows, so it cannot train anything useful.

For your model, usable training data must include actual text pairs/triplets, e.g.:
```json
{"query":"case facts text","positive":"relevant regulation article text","negative":"similar but not applicable article"}
```

So far, both open CSVs are analytics datasets, not retrieval training datasets.

---

## User

does this work? https://laws.moj.gov.sa/ar/JudicialDecisionsList/1/tHmWFpfqu2BzzaDB9cFx36ET7Yuocyka9OFhNdoiqLGxJ82QICUjU2-Co2EdTa3o

---

## Assistant (Build · gpt-5.3-codex · 4.3s)

_Thinking:_



**Tool: webfetch**

**Input:**
```json
{
  "url": "https://laws.moj.gov.sa/ar/JudicialDecisionsList/1/tHmWFpfqu2BzzaDB9cFx36ET7Yuocyka9OFhNdoiqLGxJ82QICUjU2-Co2EdTa3o",
  "format": "markdown",
  "timeout": 120
}
```

**Output:**
```
 . البوابة القانونية 

 

Loading...
```

---

## Assistant (Build · gpt-5.3-codex · 5.1s)

_Thinking:_



**Tool: webfetch**

**Input:**
```json
{
  "url": "https://laws.moj.gov.sa/ar/JudicialDecisionsList/1/tHmWFpfqu2BzzaDB9cFx36ET7Yuocyka9OFhNdoiqLGxJ82QICUjU2-Co2EdTa3o",
  "format": "html",
  "timeout": 120
}
```

**Output:**
```
<!doctype html>
<html lang="ar" dir="rtl" data-n-head="%7B%22lang%22:%7B%221%22:%22ar%22%7D,%22dir%22:%7B%221%22:%22rtl%22%7D%7D">
  <head>
    <meta data-n-head="1" charset="utf-8"><meta data-n-head="1" name="viewport" content="width=device-width,initial-scale=1"><meta data-n-head="1" data-hid="description" name="description" content="البوابة القانونية-- وزارة العدل السعودية"><title> . البوابة القانونية</title><script type="text/javascript" src="/ruxitagentjs_ICA27NVfqrux_10245220704125537.js" data-dtconfig="rid=RID_389335528|rpid=-642736131|domain=moj.gov.sa|reportUrl=/rb_bf15146xxt|uam=1|app=e2f04a7dbb2deafb|owasp=1|featureHash=ICA27NVfqrux|nsfnv=1|rdnt=1|uxrgce=1|srcss=0|cuc=yezlhxym|srxcss=0|srxicss=0|mel=100000|expw=1|dpvc=1|lastModification=1774362061790|tp=500,50,0|srbbv=2|agentUri=/ruxitagentjs_ICA27NVfqrux_10245220704125537.js"></script><link data-n-head="1" rel="icon" type="image/x-icon" href="/favicon.ico"><link rel="preload" href="/_nuxt/1d1c1f4.js" as="script"><link rel="preload" href="/_nuxt/45878cb.js" as="script"><link rel="preload" href="/_nuxt/css/7fe6aa4.css" as="style"><link rel="preload" href="/_nuxt/95549fd.js" as="script"><link rel="preload" href="/_nuxt/css/55b40b0.css" as="style"><link rel="preload" href="/_nuxt/f7bb847.js" as="script">
  <link href="/_nuxt/css/7fe6aa4.css" rel="stylesheet"><link href="/_nuxt/css/55b40b0.css" rel="stylesheet"></head>
  <body>
    <div id="__nuxt"><style>#nuxt-loading{background:#fff;visibility:hidden;opacity:0;position:absolute;left:0;right:0;top:0;bottom:0;display:flex;justify-content:center;align-items:center;flex-direction:column;animation:nuxtLoadingIn 10s ease;-webkit-animation:nuxtLoadingIn 10s ease;animation-fill-mode:forwards;overflow:hidden}@keyframes nuxtLoadingIn{0%{visibility:hidden;opacity:0}20%{visibility:visible;opacity:0}100%{visibility:visible;opacity:1}}@-webkit-keyframes nuxtLoadingIn{0%{visibility:hidden;opacity:0}20%{visibility:visible;opacity:0}100%{visibility:visible;opacity:1}}#nuxt-loading>div,#nuxt-loading>div:after{border-radius:50%;width:5rem;height:5rem}#nuxt-loading>div{font-size:10px;position:relative;text-indent:-9999em;border:.5rem solid #f5f5f5;border-left:.5rem solid #000;-webkit-transform:translateZ(0);-ms-transform:translateZ(0);transform:translateZ(0);-webkit-animation:nuxtLoading 1.1s infinite linear;animation:nuxtLoading 1.1s infinite linear}#nuxt-loading.error>div{border-left:.5rem solid #ff4500;animation-duration:5s}@-webkit-keyframes nuxtLoading{0%{-webkit-transform:rotate(0);transform:rotate(0)}100%{-webkit-transform:rotate(360deg);transform:rotate(360deg)}}@keyframes nuxtLoading{0%{-webkit-transform:rotate(0);transform:rotate(0)}100%{-webkit-transform:rotate(360deg);transform:rotate(360deg)}}</style> <script>window.addEventListener("error",(function(){var e=document.getElementById("nuxt-loading");e&&(e.className+=" error")}))</script> <div id="nuxt-loading" aria-live="polite" role="status"><div>Loading...</div></div> </div><script>window.__NUXT__={config:{BASE_URL:"https://laws.moj.gov.sa",APP_ENV:"Production",HOTJAR_KEY:5080101,_app:{basePath:"/",assetsPath:"/_nuxt/",cdnURL:null}}}</script>
  <script src="/_nuxt/1d1c1f4.js"></script><script src="/_nuxt/45878cb.js"></script><script src="/_nuxt/95549fd.js"></script><script src="/_nuxt/f7bb847.js"></script></body>
</html>

```

---

## Assistant (Build · gpt-5.3-codex · 9.2s)

_Thinking:_



Not directly, at least not from a simple API/script call.

- I tested the URL and it returns a JS app shell (`Loading...`), not decision data JSON.
- So for training pipeline, this link alone is **not immediately usable** unless you access an underlying API/export endpoint.
- It can still be useful **if** you can get:
  - full decision text
  - cited regulation/article references (or explicit links)
  - stable IDs

If you can export those fields, then yes, it becomes useful for training data creation.  
Without that, it’s mostly a webpage, not a ready dataset.

If you want, I can give you the exact minimum schema to collect from this portal so it becomes train-ready.

---

## User

this is the content of the page: what if we extract it one by one and store them then train on them is it possible: القضية رقم 4470267991 لعام 1444 هـ
المحكمة التجارية
المدينة: الدمام
رقم الحكم: 4630220365
التاريخ: ٦ رَمضان ١٤٤٦
نص الحكم الإبتدائي
الحمدلله والصلاة والسلام على رسول الله، أما بعد:
فلدى الدائرة الثامنة وبناء على القضية رقم ٤٤٧٠٢٦٧٩٩١ لعام ١٤٤٤ هـ

المدعي:
شركة (...) للتجارة والمقاولات
المدعى عليه:
شركة (...)

الوقائع:
تتلخص وقائع هذه الدعوى في أنه سبق وأن تقدم وكيل المدعية/ (...)، بصحيفة دعوى إلى المحكمة التجارية بالدمام جاء فيها: بتاريخ ١٢/٠٦/٢٠٢٠ تعاقدت المدعية شركة (...) مع المدعى عليها شركة (...) وذلك بشأن تنفيذ وتشييد أعمال انشائية بمشروع مملوك للمدعى عليها بمدينة (...) بالمنطقة (...) قيمة العقد مبلغ (٦٢,١٢٠,٠٥٠.٠٠) ، وقد قامت المدعية بتسليم المدعى عليها اثناء ابرام التعاقد عدد من الضمانات بنكية منها الضمان البنكي عن حسن الاعمال ذو الرقم (...) بمبلغ وقدرة ٦,٢١٢,٠٠٥ ستة ملايين ومائتان واثنى عشر ألف ريال وخمسة هلله وذلك بغرض ضمان حسن اعمال المشروع بالكامل(مرفق رقم ١ خطاب الضمان).وقامت موكلتي بتنفيذ عدد من الأعمال المتفق عليها خلال فترة تنفيذ الاعمال الا أن المدعى عليها قامت بوقف الاعمال وارسال خطاب بفسخ العقد ومنع المدعية من استكمال العمل (مرفق رقم ٢ خطاب الفسخ وانهاء العمل)، ثم قامت المدعى عليها بتسييل الضمان البنكي موضوع الدعوى دون وجه حق ورغم قيامها بفسخ التعاقد وعدم انتهاء المشروع وتنفيذ كامل الأعمال وهو ما سبب اضرار كبيرة للمدعية (مرفق رقم٣ ما يفيد حسم المبلغ من حساب المدعية البنكي)، ولهذا فان المدعية تقدمت بهذه الدعوى لمطالبة المدعى عليه بان ترد لها قيمة الضمان البنكي الذي قامت بتسييله دون وجه حق ودون تحقق الغرض الصادر من اجله الضمان البنكي، وعليه ومن جميع ما سبق نلتمس من فضيلتكم الحكم:أولا: إلزام المدعى عليها برد قيمة الضمان البنكي الصادر عن حسن الاعمال ذو الرقم (...) وبمبلغ وقدرة ٦,٢١٢,٠٠٥ ريال (ستة ملايين ومائتان وأثنى عشر ألف ريال وخمسة هللة) الصادر من البنك (...). ثانياً: إلزام المدعى عليها بأن تدفع للمدعية اتعاب محاماة مبلغ وقدره (٦٢٠,٠٠٠) ريال ستمائة وعشرون ألف ريال، هذه دعواي، وقدم سنداً لطلبه المستندات الآتية:١-اتفاقية الشراء الرئيسية للبضائع والخدمات، ممهورة بختم الطرفين، برقم(...).٢ خطاب ضمان الأعمال، على مطبوعات البنك (...)، ممهور بختم وتوقيع البنك، برقم (k٠٧٠٥٣٦)، وتاريخ،٢٠٢١/٠٣/١٨م. وقيدت القضية بالرقم المشار إليه أعلاه، وأحيلت إلى هذه الدائرة وباشرت نظرها حسب ما هو مثبت في محاضرها، وقد أودع وكيل المدعى عليها مذكرة الدفاع في النظام بتاريخ ٥/ ٦/ ١٤٤٤هـ ونصها كما يلي: الموضوع: مذكرة دفاع للدعوى رقم (٤٤٧٠٢٦٧٩٩١) والمقامة من شركة (...)، أولاً: نفيد الدائرة الموقرة أن المدعية قامت برفع دعوى أخرى أمام الدائرة التجارية الثانية عشرة بالمحكمة التجارية بالدمام في الموضوع ذاته برقم ٤٤٧٠٠٧١٢١٧ وتاريخ ١٨/٠٢/١٤٤٤ هـ. مرفق لفضيلتكم صحيفة دعوى المدعية في الدعوى الأخرى. (مرفق ١)، ثانياً: دفعنا الشكلي للدعوى المقامة من قبل المدعية: وفقاً للمادة الخامسة والسبعون من نظام المرافعات الشرعية والتي تضمنت على أنه يجب إبداء الدفوع الشكلية قبل أي طلب أو دفع في موضوع الدعوى، أتقدم إلى فضيلتكم بدفعنا شكلاً للدعوى المقامة من المدعية، وذلك على النحو الآتي: تضمن العقد لشرط وساطة: نصت المادة الثامنة والخمسون من اللائحة التنفيذية لنظام المحاكم التجارية على أنه يجب اللجوء إلى المصالحة والوساطة قبل قيد أي من الدعاوى المتعلقة بالعقود التي تتضمن الاتفاق - كتابة - على اللجوء إلى المصالحة والوساطة والتسوية الودية قبل اللجوء إلى القضاء. وعند النظر إلى الفقرة (٧-٤) من العقد المبرم بين موكلتي والمدعية نجد أن العقد تضمن شرط وساطة على أن تعقد في (...)، مقاطعة (...)، (...)، (...)، مما يترتب عليه وجوب اللجوء الى الوساطة في (...) قبل التوجه إلى القضاء. مرفق لفضيلتكم نسخة من العقد. (مرفق ٢)، الاختصاص القضائي الدولي: نص العقد المبرم بين موكلتي والمدعية في الفقرة (٧-٦) على أن يكون الاختصاص القضائي بشكل حصري للمحاكم في ولاية(...)، مقاطعة (...)، (...)، مما يترب عليه عدم اختصاص محاكم المملكة بالنظر في النزاعات الناشئة عن هذا العقد، النظام المختار: نص العقد المبرم بين موكلتي والمدعية في الفقرة (٧-٥) على ان يخضع العقد المبرم بين الطرفين لقوانين (...)، مما يترتب عليه عدم خضوع هذا العقد لأنظمة المملكة إعمالاً لإرادة المتعاقدين، نؤكد للدائرة الموقرة ان موكلتي تريد الاحتفاظ بحقها بالرد على موضوع الدعوى، ولكن تماشياً مع ما أتت به المادة الخامسة والسبعون من نظام المرافعات الشرعية تكتفي بدفعها شكلاً، استنادا على ما تقدم، ولئن العقد ملزم لطرفيه، لقوله تعالى ( يا أيها الذين آمنوا أوفوا بالعقود )، و لقول النبي صلى الله عليه وسلم ( المسلمون على شروطهم )، و استنادا على المادة الثامنة والخمسون من اللائحة التنفيذية لنظام المحاكم التجارية، أطلب من فضيلتكم عدم قبول دعوى المدعية وإلزامها بدفع مبلغ و قدره ٦٠٠,٠٠٠ ريال سعودي إلى موكلتي كأتعاب محاماة ا. هـ. ثم عقدت الدائرة جلسة مرئية في ٩/ ٦/ ١٤٤٤هـ وفيها حضر المشار إليهما بعالية وتشير الدائرة إلى أنها عقدت هذه الجلسة التحضيرية وذلك بعد تبلغ المدعى عليها وتبين للدائرة اختصاصها بنظر للدعوى وقبولها مبدئياً وبسؤال وكيلة المدعية عن دعوى موكلتها أحالت على صحيفة الدعوى -المشار لها بعالية-، وبعرض ذلك على وكيل المدعى عليها أفاد بأنه أرفق جوابه عبر الطلب على القضية وذلك بتاريخ ٠٥/٠٦/١٤٤٤ وبعرض ذلك على وكيلة المدعية أفادت أن لديها جواب تود إرفاقه فأرفقت عبر المحادثة ما نصه: (لرد على جواب المدعى عليها وما جاء فيه من دفوع شكلية. أولاً: ما يخص وجود دعوى أخرى منظورة أمام الدائرة التجارية الثانية عشر فهو صحيح لكن لا صلة بين الدعويين فهذه الدعوى تخص رد مبلغ خطاب الضمان المذكور بالدعوى أما الدعوى الأخرى فهي تخص رد وتسليم مستند، وعليه الدعويين مختلفين في الموضوع ثانياً: نود أن نوضح أن الدعوى المنظورة تخص المطالبة باسترداد قيمة خطاب ضمان سابق إصداره من المدعية للمدعى عليها واستقلال خطاب الضمان البنكي موضوع الدعوى عن عقد المقاولة المحرر بين الطرفين وانه يخرج عن العقد والاتفاق المحرر بينهما وما جاء فيه من بنود تخص حل النزاعات القضائية بل أن الضمان البنكي نص صراحة على (أي منازعة تخص هذا الخطاب يعتد بقوانين المملكة العربية السعودية) وعليه يكونا الاختصاص القضائي وفقاً لما ورد بالضمان يخضع لمحكمة الموضوع وهي المحكمة التجارية بالدمام. ثالثاً: الرد على ما جاء بشأن تضمن العقد لشرط الوساطة. جاء بمذكرة المدعى عليها ان بنود العقد نصت على اللجوء للوساطة قبل التقاضي إلا أن من المعروف ان الوساطة والمصالحة هو أجراء غير الزامي كون الوساطة أو المصالحة ليست جهة قضائية كالتحكيم إضافة إلى انه عند قيد الدعوى التجارية بنظام ناجز بيتم إحالتها لمنصة تراضي مباشرة من إدارة قيد الدعاوى لمحاولة الصلح ، كما ان الاتفاق الوارد في العقد عن الوساطة ذكر بان تتم الوساطة قبل صدور حكم نهائي وعليه يمكن عرض الصلح على الأطراف أثناء نظر الدعوى ولم يشترط في العقد ان تكون إجراءات الصلح قبل قيد الدعوى واستنادً للمواد (٥٩) و(٦٠) من اللائحة التنفيذية لنظام المحاكم التجارية يمكن إجراء المصالحة بعد قيد الدعوى. رابعاً: الرد على ما يخص الاختصاص القضائي الدولي. جاء بمذكرة رد المدعى عليها أن الاختصاص القضائي ينعقد لمحاكم ولاية (...) والرد على ذلك أن هذا الاتفاق يخالف المواد والقواعد الأمرة لنظام المرافعات الشرعية والتي نصت في المادة (٢٥) على (تختص محاكم المملكة بنظر الدعاوى التي ترفع على غير السعودي الذي له محل إقامة عام أو مختار في المملكة فيما عدا الدعاوى العينية المتعلقة بعقار خارج المملكة.) كما نصت الفقرة رقم (أ) من المادة (٢٦) من نظام المرافعات الشرعية على (تختص محاكم المملكة بنظر الدعاوى التي ترفع على غير السعودي الذي ليس له مكان إقامة عام أو مختار في المملكة في الأحوال الآتية:- إذا كانت الدعوى متعلقة بمال موجود في المملكة أو بالتزام تُعد المملكة مكان نشوئه أو تنفيذ)، إضافة الى ما نصت عليه الفقرة (٢) من المادة (١٧) من نظام المحاكم التجارية التي نصت على (في الدعاوى المتعلقة بالشركات، يكون الاختصاص المكاني للمحكمة التي يقع في نطاق اختصاصها المقر الرئيس للشركة، سواء كانت الدعوى على الشركة، أو من الشركة على أحد الشركاء، أو من شريك على آخر، أو على مديريها أو أعضاء مجلس إدارتها. ويجوز رفع الدعوى إلى المحكمة التي يقع في نطاق اختصاصها فرع الشركة في المنازعات الناشئة من التعاقد مع ذلك الفرع)، وعليه ولكون المدعى عليها شركة مقيدة بوزارة التجارة ولها مقر ثابت ومعلوم بالمملكة العربية السعودية وان العمل موضوع النزاع تم بالسعودية فيكون الاختصاص لمحاكم المملكة وذلك من القواعد الأمرة التي لا يجوز الاتفاق على مخالفتها وان موضوع الدعوى متعلق بمال موجود بالسعودية وهو خطاب الضمان البنكي موضوع الدعوى) ا. هـ. وبعرض ذلك على وكيل المدعى عليها تمسك بما قدم وعليه رفعت الجلسة للدراسة. وفي جلسة ٢٥/ ٦/ ١٤٤٤هـ حضر المشار لهما بعالية، وتشير الدائرة إلى أنها اطلعت على ملف القضية وسألت وكيل المدعى عليها عن موضوع الدعوى في الدائرة الأخرى في ذات المحكمة؟ أجاب هناك قضيتان: الأولى: (٤٤٧٠٠٧١٢١٧) وتطلب المدعية برد مبلغ خطاب الضمان، والثانية: (٤٤٧٠٥٢١٤١٢٥) وتطلب المدعية برد المعدات وكلها متفرعة عن نفس الموضوع، وبعرض ذلك على وكيل المدعية أجاب غير صحيح الدعوى تتعلق بخطاب ضمان آخر وتم الحكم بمنع التصرف بخطاب الضمان البنكي وهو مختلف عن الخطاب محل الدعوى. وعليه أفهمت الدائرة وكيل المدعى عليها بإرفاق صور من أحكام القضايا التي ذكرها، فاستعد بذلك، وأفهمت وكيل المدعية بإرفاق صورة خطاب الضمان البنكي فاستعد بذلك وعليه قررت الدائرة رفع الجلسة، وفي جلسة ١/ ٨/ ١٤٤٤هـ حضر المشار اليهم بعالية وتشير الدائرة إلى تقدم وكيل المدعى عليها بمذكرته بالأمس عبر النظام والمتضمنة عدد من الأحكام القضائية، ولم يتسنى الاطلاع عليها للتأخر في تقديمها، ثم أرسلت وكيلة المدعية عبر الاتصال المرئي ما نصه: (إشارة الى الدعوى المذكورة بأعلاه وبصفتي وكيلاً عن المدعي، أتقدم لفضيلكم بمذكره رد مقدمه من موكلي عما تم ذكره بالجلسة السابقة ٢٥/٠٦/١٤٤ه، وعليه أقول وبالله التوفيق. أولا: نؤكد انه ما تم ذكره من وكيل المدعي عليها انه هناك قضيتان: الأولى: (٤٤٧٠٠٧١٢١٧) وتطلب المدعية برد وتسليم خطاب الضمان والخاص بالدفعة المقدمة علما بان سبق أن صدر حكم لموكلتي من القضاء المستعجل بمنع المدعى عليها من التصرف في هذا الخطاب، والقضية الثانية: (٤٤٧٠٥٢١٤١٢٥) وتطلب المدعية برد المعدات الموجودة بالموقع لدى المدعى عليها، وهو ما يبين ان تلك القضايا وما بها من طلبات مختلفة عن القضية المنظورة أمام فضيلتكم. ثانيا: نؤكد على الضمان موضوع الدعوي هو الضمان البنكي عن حسن الأعمال ذو الرقم (...) بمبلغ وقدرة ٦,٢١٢,٠٠٥ ريال وذلك بغرض ضمان حسن أعمال المشروع بالكامل. وحيث انه المدعى عليها قامت بفسخ التعاقد مع المدعية وهو ما جعلها لا تقوم بتنفيذ كامل الأعمال ويجعل قياما لمدعى عليها بصرف وتسيل الضمان البنكي موضوع الدعوى غير صحيح لعدم استحقاقه ، ولهذا فان المدعية تقدمت بهذه الدعوى لمطالبة المدعى عليه بان ترد لها قيمة الضمان البنكي الذي قامت بتسييله دون وجه حق ودون تحقق الغرض الصادر من أجلة الضمان البنكي، وعليه ومن جميع ما سبق نلتمس من فضيلتكم الحكم:أولا: إلزام المدعى عليها برد قيمة الضمان البنكي الصادر عن حسن الأعمال ذو الرقم (...) وبمبلغ وقدرة ٦,٢١٢,٠٠٥ ريال (ستة ملايين ومائتان وأثنى عشر ألف ريال وخمسة هللة) الصادر من البنك (...). ثانياً: إلزام المدعى عليها بان تدفع للمدعية أتعاب محاماة مبلغ وقدره ٦٢٠٠٠٠ريال ستمائة وعشرون ألف ريال وتقبلوا خالص التحية والتقدير) ا. هـ. وعليه جرى إفهام وكيل المدعى عليها بالجواب الموضوعي عن الدعوى خلال عشرة أيام من تاريخه، ولوكيلة المدعية ذات المهلة للرد، وللاطلاع على ما سبق الإشارة إليه، رفعت الجلسة، وفي جلسة هذا اليوم حضر المشار لهما بعالية، وتشير الدائرة إلى تبادل الأطراف المذكرات عبر النظام، وبعد الاطلاع على ملف القضية، ولصلاحية الدعوى للفصل فيها رفعت الجلسة للمداولة والنطق بالحكم، فحكمت الدائرة بعدم اختصاص المحاكم التجارية بالمملكة العربية السعودية دولياً بنظر الدعوى المقامة من المدعية/ شركة (...) للتجارة والمقاولات سجل تجاري رقم: (...)، ضد المدعى عليها/ شركة (...) سجل تجاري رقم: (...)، ثم قدم وكيل المدعية اعتراضه على الحكم فأحيلت إلى الاستئناف، بما أن واقعات هذه القضية أحاط بها الحكم محل الاعتراض، لذلك فإن دائرة الاستئناف تحيل عليه درءاً للتكرار، بموجب ما نصت عليه المادة (٧٦/٢) من نظام المحاكم التجارية، أن تقدمت وكيل المدعية بهذه الدعوى أنه بتاريخ ١٢/٠٦/٢٠٢٠ تعاقدت المدعية شركة (...) مع المدعى عليها شركة (...) وذلك بشأن تنفيذ وتشييد أعمال إنشائية بمشروع مملوك للمدعى عليها بمدينة (...) بالمنطقة (...) قيمة العقد مبلغ (٦٢,١٢٠,٠٥٠.٠٠) ، وقد قامت المدعية بتسليم المدعى عليها أثناء إبرام التعاقد عدد من الضمانات بنكية منها الضمان البنكي عن حسن الأعمال ذو الرقم (...) بمبلغ وقدرة ٦,٢١٢,٠٠٥ ستة ملايين ومائتان واثنى عشر ألف ريال وخمسة هلله وذلك بغرض ضمان حسن أعمال المشروع بالكامل. وقامت موكلتي بتنفيذ عدد من الأعمال المتفق عليها خلال فترة تنفيذ الأعمال إلا أن المدعى عليها قامت بوقف الأعمال وأرسال خطاب بفسخ العقد ومنع المدعية من استكمال العمل، ثم قامت المدعى عليها بتسييل الضمان البنكي موضوع الدعوى دون وجه حق ورغم قيامها بفسخ التعاقد وعدم انتهاء المش 

---

## Assistant (Build · gpt-5.3-codex · 10.4s)

_Thinking:_



Yes, **possible**, but with one key condition:

- If you only collect judgment text like this, it is **not enough** for your target task (`case -> relevant regulation article`) supervised fine-tuning.
- You need to also extract, for each case, at least one **ground-truth regulation/article** (positive label).

What works:
- **Best**: `case_text + linked regulation article text + hard negatives`
- Data row example:
```json
{"query":"<case facts>", "positive":"<article text>", "negative":"<similar non-applicable article>"}
```

Can you extract one-by-one?
- Yes, and quality can be high.
- Even `500–2000` high-quality labeled examples is useful.
- But manual extraction is slow, so start with a small gold set first.

Important before scraping:
- Check portal **terms/license**, robots policy, and legal/privacy rules.
- Don’t store sensitive personal identifiers.

So: your page content is good raw material, but you still need the **case-to-article labels** to make it truly trainable for retrieval fine-tuning.

---

## User

i don't understand what you are saying, what is the condition

---

## Assistant (Build · gpt-5.3-codex · 6.8s)

Condition = each case must have a **known correct law article** linked to it.

- Not enough: case text alone.
- Required:  
  - case text  
  - correct regulation/article text (or id)  
  - optional wrong similar article (negative)

Think of one training row like:
```json
{
  "case_text": "employee terminated without notice ...",
  "correct_article": "Labor Law Article X ...",
  "wrong_article": "Labor Law Article Y ..."
}
```

If you only have:
- city, date, case type, reference number, or
- long judgment text without article label,

then the model does not know what the “right answer” is, so fine-tuning for your retrieval task won’t work well.

So the condition is simple: **case -> correct article mapping must exist**.

---

## User

usually they don't say that the case is related to specific regulation, but it may mention the regulation inside the case description like saying:  وفقاً للمادة الخامسة والسبعون من نظام المرافعات الشرعية

---

## Assistant (Build · gpt-5.3-codex · 8.2s)

_Thinking:_



Exactly — that’s the key.  
If the judgment text contains citations like **"وفقاً للمادة الخامسة والسبعون من نظام المرافعات الشرعية"**, you can use that.

So your condition becomes:

- Each case should have at least one **extractable citation**:
  - regulation name (`نظام المرافعات الشرعية`)
  - article number (`75`)

That can be converted into labels:
- `query` = case text (or facts section)
- `positive` = full text of cited article 75 from that regulation
- `negative` = other articles from same regulation or similar regulations

So yes, you *can* train from these judgments, using **citation extraction** as weak supervision.

Very practical plan:
1. Extract citations from cases (regex/rules for `المادة ... من نظام ...`).
2. Map citation to canonical regulation+article text.
3. Build triplets `(case, cited_article, hard_negative_article)`.
4. Manually review 200–500 samples first to ensure extraction quality.
5. Train.

So you’re not blocked — this is a valid path even without explicit case↔regulation labels.

---

## User

so i just need to give a case id and case description and you can do the rest with training it?

---

## Assistant (Build · gpt-5.3-codex · 5.6s)

_Thinking:_



Almost — **case id + case description alone is not enough** for final training.

Minimum I need to do the rest:

- `case_id`
- `case_text` (description/judgment)
- a **regulation corpus** (all laws + article texts) to map citations to actual article text

Then I can do:
1. Extract citations from case text (`المادة X من نظام Y`).
2. Map them to the real article text in your corpus.
3. Generate training triplets automatically.
4. Fine-tune BGE-M3.
5. Evaluate and give you the new model.

So yes, I can handle the pipeline — but you must provide:
- case texts, and
- the law articles dataset (or API/source for it).

---

## User

we have the regulations ready and normalized in our database and you check the setup on our code we also have workers to do that

---

## Assistant (Build · gpt-5.3-codex · 5.8s)

_Thinking:_



**Tool: glob**

**Input:**
```json
{
  "pattern": "**/ai_service/**"
}
```

**Output:**
```
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/.DS_Store
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/__pycache__/test_integration.cpython-313-pytest-8.4.2.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/__pycache__/test_phase3_colbert.cpython-313-pytest-8.4.2.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/test_phase3_colbert.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/__pycache__/colbert_retriever.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/colbert_retriever.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/__pycache__/find_related.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/schemas/__pycache__/responses.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/schemas/__pycache__/requests.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/__pycache__/config.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/find_related.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/schemas/responses.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/schemas/requests.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/config.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/__pycache__/test_phase3_agentic.cpython-313-pytest-8.4.2.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/__pycache__/agentic_retriever.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/test_phase3_agentic.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/agentic_retriever.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/__pycache__/test_phase2_reranking_hyde.cpython-313-pytest-8.4.2.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/__pycache__/reranker.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/__pycache__/hyde.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/test_phase2_reranking_hyde.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/hyde.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/reranker.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/__pycache__/test_find_related_pipeline.cpython-313-pytest-8.4.2.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/__pycache__/llm_verifier.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/test_find_related_pipeline.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/llm_verifier.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/ocr/__pycache__/factory.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/__pycache__/extraction.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/extraction.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/ocr/factory.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/venv/lib/python3.13/site-packages/arabic_reshaper/__pycache__/reshaper_config.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/venv/lib/python3.13/site-packages/arabic_reshaper/__pycache__/letters.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/venv/lib/python3.13/site-packages/arabic_reshaper/reshaper_config.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/venv/lib/python3.13/site-packages/arabic_reshaper/__pycache__/__init__.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/venv/lib/python3.13/site-packages/arabic_reshaper/arabic_reshaper.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/__pycache__/similarity.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/__pycache__/embeddings.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/__pycache__/deps.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/__pycache__/document_insights.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/similarity.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/document_insights.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/embeddings.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/deps.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/test_integration.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/__pycache__/test_similarity_core.cpython-313-pytest-8.4.2.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/__pycache__/test_integration_manual.cpython-313-pytest-8.4.2.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/__pycache__/test_api.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/__pycache__/test_api.cpython-313-pytest-8.4.2.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/test_api.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/__pycache__/regulation_insights.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/regulation_insights.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/__pycache__/__init__.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/__init__.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/__pycache__/main.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/main.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/__pycache__/regulation_extract.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/__pycache__/document_extract.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/__pycache__/assistant.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/assistant.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/regulation_extract.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/document_extract.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/utils/__pycache__/__init__.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/utils/__pycache__/logger.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/__pycache__/test_similarity_core.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/__pycache__/test_integration.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/__pycache__/test_integration_manual.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/__pycache__/__init__.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/experiments/__pycache__/eval_bge_m3.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/experiments/__pycache__/eval_alarb_via_api.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/experiments/__pycache__/eval_alarb_retrieval.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/experiments/__pycache__/eval_alarb_dataset.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/__pycache__/models.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/ocr/__pycache__/__init__.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/__pycache__/embeddings.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/__pycache__/__init__.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/schemas/__pycache__/__init__.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/__pycache__/similarity.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/__pycache__/health.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/__pycache__/__init__.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/__pycache__/__init__.cpython-313.pyc
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/ocr/__init__.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/utils/logger.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/test_similarity_core.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/test_integration_manual.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/utils/__init__.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/experiments/eval_alarb_via_api.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/experiments/eval_alarb_retrieval.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/experiments/eval_bge_m3.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/tests/__init__.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/experiments/eval_alarb_dataset.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/embeddings.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/__init__.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/models.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/schemas/__init__.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/health.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/similarity.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/api/__init__.py
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/__init__.py

(Results are truncated: showing first 100 results. Consider using a more specific path or pattern.)
```

**Tool: glob**

**Input:**
```json
{
  "pattern": "**/*tune-case-link-scoring*.ts"
}
```

**Output:**
```
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System/src/scripts/tune-case-link-scoring.ts
```

**Tool: grep**

**Input:**
```json
{
  "pattern": "tune-case-link-scoring|find_related|embeddings|worker|regulation",
  "path": "/Users/salehalobaylan/Desktop/Silah-Legal",
  "include": "*.{py,ts,tsx,js,json,md}"
}
```

**Output:**
```
Found 6151 matches (showing first 100)
/Users/salehalobaylan/Desktop/Silah-Legal/Legal_Case_Management_Website/package-lock.json:
  Line 1695:         "jest-worker": "^29.7.0",
  Line 7807:         "jest-worker": "^29.7.0",
  Line 8077:         "jest-worker": "^29.7.0",
  Line 8313:     "node_modules/jest-worker": {
  Line 8315:       "resolved": "https://registry.npmjs.org/jest-worker/-/jest-worker-29.7.0.tgz",
  Line 8329:     "node_modules/jest-worker/node_modules/supports-color": {

/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System/package-lock.json:
  Line 2090:         "jest-worker": "^29.7.0",
  Line 3786:         "@cloudflare/workers-types": ">=4",
  Line 3818:         "@cloudflare/workers-types": {
  Line 5883:         "jest-worker": "^29.7.0",
  Line 6048:         "jest-worker": "^29.7.0",
  Line 6268:     "node_modules/jest-worker": {
  Line 6270:       "resolved": "https://registry.npmjs.org/jest-worker/-/jest-worker-29.7.0.tgz",
  Line 6284:     "node_modules/jest-worker/node_modules/supports-color": {

/Users/salehalobaylan/Desktop/Silah-Legal/DESIGN_CHAPTER_PROMPTS.md:
  Line 40:    - /similarity/find-related — case-to-regulation ranking
  Line 41:    - /regulations/* — extract, summary-analysis, amendment-impact
  Line 50:      * regulation_chunks — 1024-dim embeddings
  Line 51:      * document_chunks — 1024-dim embeddings
  Line 55:    - Ministry of Justice (Najiz / MOJ) — regulation source sync
  Line 82: 2. **Application Layer**: A Node.js/Fastify 5 API server orchestrates all business logic — authentication, case and client management, regulation monitoring, document processing, billing, and real-time notifications via Socket.IO. Organization-scoped rooms (`org:{orgId}`) and user-scoped rooms (`user:{userId}`) are maintained for targeted event delivery.
  Line 83: 3. **Intelligence Layer**: A Python/FastAPI microservice provides a staged AI pipeline. Its `/similarity/find-related` endpoint combines dense vector retrieval (BGE-M3 embeddings), lexical matching (Jaccard), category priors, optional HyDE query expansion, optional ColBERT late-interaction scoring, cross-encoder reranking (BGE-Reranker-v2-m3), and optional Gemini-backed LLM verification. Feature toggles are stored per-organization in `ai_settings` and passed at request time.
  Line 84: 4. **Data Layer**: PostgreSQL with the pgvector extension stores all relational data and 1024-dimensional embeddings for both regulation chunks and document chunks. Drizzle ORM provides type-safe schema definitions and migrations.
  Line 85: 5. **External Integrations**: The Ministry of Justice (MOJ/Najiz) is the canonical source for Saudi regulations. Google OAuth 2.0 enables SSO. Gemini API provides LLM-based suggestion verification.
  Line 131:    Fields: id (PK), title, regulation_number, source_url, source_provider,
  Line 137:    Fields: id (PK), regulation_id (FK), version_number, content, content_hash,
  Line 142:    Fields: id (PK), regulation_id (FK), regulation_version_id (FK),
  Line 148:    Fields: id (PK), regulation_id (FK), regulation_version_id (FK),
  Line 154:    Fields: id (PK), regulation_id (FK), from_version_id (FK), to_version_id (FK),
  Line 160:     Fields: id (PK), user_id (FK), organization_id (FK), regulation_id (FK),
  Line 172:     Fields: id (PK), case_id (FK), regulation_id (FK),
  Line 173:             matched_regulation_version_id (FK→regulation_versions),
  Line 209:             related_case_id, related_regulation_id, read, read_at, created_at
  Line 213:             ai_suggestions, regulation_updates, case_updates, system_alerts,
  Line 311:         regulation_number: VARCHAR(100) — "Official MOJ regulation number"
  Line 325:         regulation_id: UUID (FK → regulations.id)
  Line 326:         regulation_version_id: UUID (FK → regulation_versions.id)
  Line 339:         regulation_id: UUID (FK → regulations.id)
  Line 340:         matched_regulation_version_id: UUID (FK → regulation_versions.id)
  Line 348:         matched_with_documents: BOOLEAN — "Whether doc embeddings influenced match"
  Line 364:         min_pair_score: DECIMAL — "Minimum score per (case, regulation) pair"
  Line 448:   + verify(caseText: String, regulationText: String): VerificationResult
  Line 451:   + expand(query: String): List[String]  // hypothetical document embeddings
  Line 470:   + generateInsights(regulationId: UUID, lang: String): RegulationInsights
  Line 471:   + refreshInsights(regulationId: UUID): void
  Line 538: - Ministry of Justice (MOJ) — external regulation source
  Line 556:   Output: hypothetical regulation passages (expanded queries)
  Line 561:   Index: regulation_chunks.embedding in pgvector (D2)
  Line 562:   Output: top-K regulation chunks with cosine scores
  Line 569:     - Category prior: case_type ↔ regulation.category match (weight from D5)
  Line 574:   Input: query embedding + candidate chunk token embeddings
  Line 579:   Input: top-N (case, regulation excerpt) pairs
  Line 594:   Output → D4: stored case_regulation_links
  Line 598:   MOJ → Regulation Monitor → D2 (new regulation_versions + re-embed chunks)
  Line 662: AI Microservice → DB: pgvector ANN search on regulation_chunks.embedding
  Line 666: AI Microservice → AI Microservice: filter by min_score, deduplicate per regulation
  Line 669:   regulation_id, title, similarity_score, method,
  Line 673: Backend → DB: INSERT INTO case_regulation_links (bulk upsert)
  Line 684: Frontend → Lawyer: Display ranked regulation links with score breakdown
  Line 692: - Show alt fragment: [if no regulations found] → return empty links
  Line 766:    Do: Track document additions, regulation links, hearing dates
  Line 792: - generateLinks() → triggers AI regulation linking
  Line 823: | regulation_updated      | org:{orgId}       | Monitor detects a regulation change      |
  Line 824: | case-links-refreshed    | user:{userId}     | Case regulation links refreshed          |
  Line 832: - On "regulation_updated" → invalidate useRegulations query, show toast
  Line 876:             table: "regulation_chunks",
  Line 883:     candidateChunks ← DEDUPLICATE(candidateChunks, by: regulation_id)
  Line 890:         categoryScore ← (chunk.regulationCategory == caseType) ? 1.0 : 0.0
  Line 891:         supportScore ← countSupportingChunks(chunk.regulation_id, queries) / MAX_CHUNKS
  Line 901:                 regulation_id: chunk.regulation_id,
  Line 909:     scoredCandidates ← DEDUP_AND_MAX(scoredCandidates, by: regulation_id)
  Line 943:         regulation_id: item.regulation_id,
  Line 944:         title: item.regulation.title,
  Line 954:         excerpt: extractExcerpt(item.regulation.content, 250)
  Line 1127: // POST /api/regulations/monitor/run  (also runs on schedule)
  Line 1130:     runRecord ← DB.insert("regulation_monitor_runs", {
  Line 1139:         "SELECT DISTINCT regulation_id, source_url FROM regulation_subscriptions
  Line 1175:                 // Step 3: Create new regulation version
  Line 1177:                     "SELECT MAX(version_number) FROM regulation_versions
  Line 1178:                      WHERE regulation_id = ?", [sub.regulation_id]
  Line 1184:                 newVersionId ← DB.insert("regulation_versions", {
  Line 1185:                     regulation_id: sub.regulation_id,
  Line 1198:                     DB.upsert("regulation_chunks", {
  Line 1199:                         regulation_id: sub.regulation_id,
  Line 1200:                         regulation_version_id: newVersionId,
  Line 1211:                 queueJob("regulation:insights", { regulation_id: sub.regulation_id, version_id: newVersionId })
  Line 1213:                     queueJob("regulation:amendment-impact", {
  Line 1214:                         regulation_id: sub.regulation_id,
  Line 1222:                     "SELECT DISTINCT user_id FROM regulation_subscriptions
  Line 1223:                      WHERE regulation_id = ? AND is_active = TRUE",
  Line 1224:                     [sub.regulation_id]
  Line 1228:                         type: "regulation_update",
  Line 1230:                         message: "A regulation you follow has been updated",
  Line 1231:                         related_regulation_id: sub.regulation_id
  Line 1233:                     websocket.emitToUser(subscriber.user_id, "regulation_updated", {
  Line 1234:                         regulation_id: sub.regulation_id,
  Line 1240:                 DB.update("regulation_subscriptions", {
  Line 1252:             LOG.error("Monitor failed for", sub.regulation_id, error)
  Line 1256:     DB.update("regulation_monitor_runs", {
  Line 1266:     DB.update("regulation_subscriptions SET next_check_at = NOW() + INTERVAL ? hours",
  Line 1445: // user_activities, ai_settings, regulation_subscriptions, invoices, etc.

(Results truncated: showing 100 of 6151 matches (6051 hidden). Consider using a more specific path or pattern.)
```

---

## Assistant (Build · gpt-5.3-codex · 25.9s)

_Thinking:_



**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System/src/scripts/tune-case-link-scoring.ts"
}
```

**Output:**
```
<path>/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System/src/scripts/tune-case-link-scoring.ts</path>
<type>file</type>
<content>1: import { desc, eq, inArray } from "drizzle-orm";
2: import { mkdirSync, writeFileSync } from "fs";
3: import { dirname, resolve } from "path";
4: import { env } from "../config/env";
5: import { db } from "../db/connection";
6: import {
7:   caseRegulationLinks,
8:   cases,
9:   regulations,
10:   regulationVersions,
11:   type CaseType,
12: } from "../db/schema";
13: import type {
14:   SimilarityMatch,
15:   SimilarityRegulationCandidate,
16: } from "../services/ai-client.service";
17: import { AIClientService } from "../services/ai-client.service";
18: import { RegulationRagService } from "../services/regulation-rag.service";
19: import { logger } from "../utils/logger";
20: 
21: type SampleRow = {
22:   caseId: number;
23:   regulationId: number;
24:   label: 0 | 1;
25:   semanticMax: number;
26:   supportCoverage: number;
27:   lexicalOverlap: number;
28:   categoryPrior: number;
29:   hasCaseSupport: boolean;
30:   strongSupportCount: number;
31: };
32: 
33: type EvaluationMetrics = {
34:   precision: number;
35:   recall: number;
36:   f1: number;
37:   accuracy: number;
38:   caseHitRate: number;
39:   tp: number;
40:   fp: number;
41:   fn: number;
42:   tn: number;
43: };
44: 
45: type ScoringProfile = {
46:   semanticWeight: number;
47:   supportWeight: number;
48:   lexicalWeight: number;
49:   categoryWeight: number;
50:   strictMinFinalScore: number;
51:   strictMinSupportingMatches: number;
52:   requireCaseSupport: boolean;
53: };
54: 
55: function mapCaseTypeToRegulationCategory(caseType: CaseType | null | undefined) {
56:   switch (caseType) {
57:     case "labor":
58:       return "labor_law";
59:     case "commercial":
60:       return "commercial_law";
61:     case "civil":
62:       return "civil_law";
63:     case "criminal":
64:       return "criminal_law";
65:     case "administrative":
66:       return "procedural_law";
67:     default:
68:       return null;
69:   }
70: }
71: 
72: function makeRng(seed: number) {
73:   let state = seed >>> 0;
74:   return () => {
75:     state = (state + 0x6d2b79f5) | 0;
76:     let t = Math.imul(state ^ (state >>> 15), 1 | state);
77:     t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
78:     return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
79:   };
80: }
81: 
82: function shuffleInPlace<T>(items: T[], rng: () => number) {
83:   for (let i = items.length - 1; i > 0; i -= 1) {
84:     const j = Math.floor(rng() * (i + 1));
85:     [items[i], items[j]] = [items[j]!, items[i]!];
86:   }
87: }
88: 
89: function parseArg(name: string, fallback: number): number {
90:   const prefixed = `${name}=`;
91:   const arg = process.argv.find((item) => item.startsWith(prefixed));
92:   if (!arg) {
93:     return fallback;
94:   }
95:   const value = Number.parseInt(arg.slice(prefixed.length), 10);
96:   return Number.isFinite(value) ? value : fallback;
97: }
98: 
99: function parseArgFloat(name: string, fallback: number): number {
100:   const prefixed = `${name}=`;
101:   const arg = process.argv.find((item) => item.startsWith(prefixed));
102:   if (!arg) {
103:     return fallback;
104:   }
105:   const value = Number.parseFloat(arg.slice(prefixed.length));
106:   return Number.isFinite(value) ? value : fallback;
107: }
108: 
109: function parseArgString(name: string, fallback: string): string {
110:   const prefixed = `${name}=`;
111:   const arg = process.argv.find((item) => item.startsWith(prefixed));
112:   if (!arg) {
113:     return fallback;
114:   }
115:   return arg.slice(prefixed.length) || fallback;
116: }
117: 
118: function normalizeWeights(profile: Pick<
119:   ScoringProfile,
120:   "semanticWeight" | "supportWeight" | "lexicalWeight" | "categoryWeight"
121: >) {
122:   const sum =
123:     profile.semanticWeight +
124:     profile.supportWeight +
125:     profile.lexicalWeight +
126:     profile.categoryWeight;
127:   if (sum <= 0) {
128:     return {
129:       semanticWeight: 0.55,
130:       supportWeight: 0.2,
131:       lexicalWeight: 0.15,
132:       categoryWeight: 0.1,
133:     };
134:   }
135:   return {
136:     semanticWeight: profile.semanticWeight / sum,
137:     supportWeight: profile.supportWeight / sum,
138:     lexicalWeight: profile.lexicalWeight / sum,
139:     categoryWeight: profile.categoryWeight / sum,
140:   };
141: }
142: 
143: function evaluateProfile(
144:   rows: SampleRow[],
145:   positivesByCase: Map<number, Set<number>>,
146:   profile: ScoringProfile
147: ): EvaluationMetrics {
148:   const weights = normalizeWeights(profile);
149:   let tp = 0;
150:   let fp = 0;
151:   let fn = 0;
152:   let tn = 0;
153: 
154:   const positiveHitByCase = new Map<number, boolean>();
155:   for (const caseId of positivesByCase.keys()) {
156:     positiveHitByCase.set(caseId, false);
157:   }
158: 
159:   for (const row of rows) {
160:     const score =
161:       weights.semanticWeight * row.semanticMax +
162:       weights.supportWeight * row.supportCoverage +
163:       weights.lexicalWeight * row.lexicalOverlap +
164:       weights.categoryWeight * row.categoryPrior;
165: 
166:     const predictedPositive =
167:       score >= profile.strictMinFinalScore &&
168:       row.strongSupportCount >= profile.strictMinSupportingMatches &&
169:       (!profile.requireCaseSupport || row.hasCaseSupport);
170: 
171:     if (predictedPositive && row.label === 1) {
172:       tp += 1;
173:       positiveHitByCase.set(row.caseId, true);
174:     } else if (predictedPositive && row.label === 0) {
175:       fp += 1;
176:     } else if (!predictedPositive && row.label === 1) {
177:       fn += 1;
178:     } else {
179:       tn += 1;
180:     }
181:   }
182: 
183:   const precision = tp / Math.max(1, tp + fp);
184:   const recall = tp / Math.max(1, tp + fn);
185:   const f1 = (2 * precision * recall) / Math.max(1e-9, precision + recall);
186:   const accuracy = (tp + tn) / Math.max(1, tp + fp + fn + tn);
187: 
188:   const caseCount = positivesByCase.size;
189:   let caseHits = 0;
190:   for (const hit of positiveHitByCase.values()) {
191:     if (hit) {
192:       caseHits += 1;
193:     }
194:   }
195:   const caseHitRate = caseHits / Math.max(1, caseCount);
196: 
197:   return {
198:     precision,
199:     recall,
200:     f1,
201:     accuracy,
202:     caseHitRate,
203:     tp,
204:     fp,
205:     fn,
206:     tn,
207:   };
208: }
209: 
210: function buildCandidateProfiles(): ScoringProfile[] {
211:   const semanticWeights = [0.45, 0.5, 0.55, 0.6, 0.65];
212:   const supportWeights = [0.15, 0.2, 0.25, 0.3];
213:   const lexicalWeights = [0.05, 0.1, 0.15, 0.2];
214:   const categoryWeights = [0.0, 0.05, 0.1, 0.15];
215:   const strictMinFinals = Array.from({ length: 21 }, (_, idx) =>
216:     Number((0.45 + idx * 0.02).toFixed(2))
217:   );
218:   const strictMinSupporting = [1, 2, 3];
219: 
220:   const candidates: ScoringProfile[] = [];
221:   for (const semanticWeight of semanticWeights) {
222:     for (const supportWeight of supportWeights) {
223:       for (const lexicalWeight of lexicalWeights) {
224:         for (const categoryWeight of categoryWeights) {
225:           for (const strictMinFinalScore of strictMinFinals) {
226:             for (const strictMinSupportingMatches of strictMinSupporting) {
227:               candidates.push({
228:                 semanticWeight,
229:                 supportWeight,
230:                 lexicalWeight,
231:                 categoryWeight,
232:                 strictMinFinalScore,
233:                 strictMinSupportingMatches,
234:                 requireCaseSupport: true,
235:               });
236:             }
237:           }
238:         }
239:       }
240:     }
241:   }
242:   return candidates;
243: }
244: 
245: function scoreBreakdownFromMatch(match: SimilarityMatch | undefined) {
246:   return {
247:     semanticMax: match?.score_breakdown?.semantic_max ?? 0,
248:     supportCoverage: match?.score_breakdown?.support_coverage ?? 0,
249:     lexicalOverlap: match?.score_breakdown?.lexical_overlap ?? 0,
250:     categoryPrior: match?.score_breakdown?.category_prior ?? 0,
251:     hasCaseSupport: Boolean(match?.score_breakdown?.has_case_support ?? false),
252:     strongSupportCount: Math.max(
253:       0,
254:       Number(match?.score_breakdown?.strong_support_count ?? 0)
255:     ),
256:   };
257: }
258: 
259: async function run() {
260:   const maxCases = parseArg("--max-cases", 40);
261:   const negativesPerCase = parseArg("--negatives-per-case", 15);
262:   const minRecallTarget = parseArgFloat("--min-recall", 0.35);
263:   const seed = parseArg("--seed", 42);
264:   const outPathArg = parseArgString(
265:     "--out",
266:     "./reports/case-link-tuning-report.json"
267:   );
268:   const outPath = resolve(outPathArg);
269: 
270:   if (!env.AI_SERVICE_URL) {
271:     throw new Error("AI_SERVICE_URL is required for scoring calibration");
272:   }
273: 
274:   const health = await fetch(`${env.AI_SERVICE_URL.replace(/\/+$/, "")}/health/`);
275:   if (!health.ok) {
276:     throw new Error(`AI service is not healthy (status=${health.status})`);
277:   }
278: 
279:   const verifiedRows = await db
280:     .select({
281:       caseId: caseRegulationLinks.caseId,
282:       regulationId: caseRegulationLinks.regulationId,
283:     })
284:     .from(caseRegulationLinks)
285:     .where(eq(caseRegulationLinks.verified, true));
286: 
287:   if (verifiedRows.length === 0) {
288:     throw new Error(
289:       "No verified links found. Need verified case-regulation links for calibration."
290:     );
291:   }
292: 
293:   const positivesByCase = new Map<number, Set<number>>();
294:   for (const row of verifiedRows) {
295:     if (!positivesByCase.has(row.caseId)) {
296:       positivesByCase.set(row.caseId, new Set());
297:     }
298:     positivesByCase.get(row.caseId)?.add(row.regulationId);
299:   }
300: 
301:   const caseIds = Array.from(positivesByCase.keys());
302:   const caseRows = await db
303:     .select({
304:       id: cases.id,
305:       title: cases.title,
306:       description: cases.description,
307:       caseType: cases.caseType,
308:       status: cases.status,
309:       courtJurisdiction: cases.courtJurisdiction,
310:       clientInfo: cases.clientInfo,
311:     })
312:     .from(cases)
313:     .where(inArray(cases.id, caseIds));
314: 
315:   const casesById = new Map(caseRows.map((row) => [row.id, row]));
316:   const eligibleCaseIds = caseIds.filter((caseId) => casesById.has(caseId));
317:   if (eligibleCaseIds.length === 0) {
318:     throw new Error("No eligible cases found for verified links");
319:   }
320: 
321:   const rng = makeRng(seed);
322:   shuffleInPlace(eligibleCaseIds, rng);
323:   const sampledCaseIds = eligibleCaseIds.slice(0, Math.max(1, maxCases));
324: 
325:   const regulationRows = await db.query.regulations.findMany({
326:     columns: {
327:       id: true,
328:       title: true,
329:       category: true,
330:       summary: true,
331:     },
332:   });
333:   const regulationsById = new Map(regulationRows.map((row) => [row.id, row]));
334: 
335:   const versionRows = await db.query.regulationVersions.findMany({
336:     columns: {
337:       id: true,
338:       regulationId: true,
339:       versionNumber: true,
340:       content: true,
341:     },
342:     orderBy: [desc(regulationVersions.versionNumber)],
343:   });
344:   const latestVersionByRegulationId = new Map<
345:     number,
346:     {
347:       id: number;
348:       regulationId: number;
349:       versionNumber: number;
350:       content: string;
351:     }
352:   >();
353:   for (const row of versionRows) {
354:     if (!latestVersionByRegulationId.has(row.regulationId)) {
355:       latestVersionByRegulationId.set(row.regulationId, row);
356:     }
357:   }
358: 
359:   const aiService = new AIClientService();
360:   const ragService = new RegulationRagService(db, aiService);
361:   const sampleRows: SampleRow[] = [];
362: 
363:   for (const caseId of sampledCaseIds) {
364:     const caseRow = casesById.get(caseId);
365:     if (!caseRow) {
366:       continue;
367:     }
368:     const positives = positivesByCase.get(caseId) ?? new Set<number>();
369:     if (positives.size === 0) {
370:       continue;
371:     }
372: 
373:     const primaryCaseText = `${caseRow.title}\n\n${caseRow.description || ""}`.trim();
374:     const preferredCategory = mapCaseTypeToRegulationCategory(caseRow.caseType);
375: 
376:     const allNegativeRegs = regulationRows.filter((reg) => !positives.has(reg.id));
377:     const sameCategory = preferredCategory
378:       ? allNegativeRegs.filter((reg) => reg.category === preferredCategory)
379:       : [];
380:     const otherCategory = allNegativeRegs.filter(
381:       (reg) => !preferredCategory || reg.category !== preferredCategory
382:     );
383:     shuffleInPlace(sameCategory, rng);
384:     shuffleInPlace(otherCategory, rng);
385: 
386:     const selectedNegativeIds = new Set<number>();
387:     for (const reg of sameCategory) {
388:       if (selectedNegativeIds.size >= negativesPerCase) {
389:         break;
390:       }
391:       selectedNegativeIds.add(reg.id);
392:     }
393:     for (const reg of otherCategory) {
394:       if (selectedNegativeIds.size >= negativesPerCase) {
395:         break;
396:       }
397:       selectedNegativeIds.add(reg.id);
398:     }
399: 
400:     const candidateIds = Array.from(
401:       new Set([...Array.from(positives.values()), ...Array.from(selectedNegativeIds)])
402:     );
403:     if (candidateIds.length === 0) {
404:       continue;
405:     }
406: 
407:     const chunkRetrieval = await ragService.retrieveTopCandidateChunks({
408:       queryText: primaryCaseText,
409:       topK: Math.max(env.REG_LINK_PREFILTER_TOP_K, candidateIds.length * 3),
410:       perRegulationLimit: env.REG_LINK_CANDIDATE_CHUNKS_PER_REG,
411:     });
412: 
413:     const candidates: SimilarityRegulationCandidate[] = [];
414:     for (const regulationId of candidateIds) {
415:       const regulation = regulationsById.get(regulationId);
416:       if (!regulation) {
417:         continue;
418:       }
419:       const latestVersion = latestVersionByRegulationId.get(regulationId);
420:       const versionChunks =
421:         latestVersion && chunkRetrieval.byRegulationVersionId.get(latestVersion.id)
422:           ? chunkRetrieval.byRegulationVersionId.get(latestVersion.id)
423:           : [];
424: 
425:       candidates.push({
426:         id: regulation.id,
427:         title: regulation.title,
428:         category: regulation.category,
429:         regulation_version_id: latestVersion?.id || null,
430:         content_text:
431:           latestVersion?.content?.slice(0, env.CASE_LINK_DOC_TOTAL_MAX_CHARS) ||
432:           regulation.summary ||
433:           regulation.title,
434:         candidate_chunks: versionChunks?.map((chunk) => ({
435:           chunk_id: chunk.chunkId,
436:           chunk_index: chunk.chunkIndex,
437:           line_start: chunk.lineStart,
438:           line_end: chunk.lineEnd,
439:           article_ref: chunk.articleRef,
440:           text: chunk.text,
441:         })),
442:       });
443:     }
444: 
445:     if (!candidates.length) {
446:       continue;
447:     }
448: 
449:     const matches = await aiService.findRelatedRegulations(primaryCaseText, candidates, {
450:       topK: candidates.length,
451:       threshold: env.CASE_LINK_SUPPORT_FLOOR,
452:       strictMode: false,
453:       caseFragments: [
454:         {
455:           fragment_id: "case:primary",
456:           text: primaryCaseText,
457:           source: "case",
458:         },
459:       ],
460:       caseProfile: {
461:         case_id: caseRow.id,
462:         title: caseRow.title,
463:         description: caseRow.description,
464:         case_type: caseRow.caseType,
465:         status: caseRow.status,
466:         court_jurisdiction: caseRow.courtJurisdiction,
467:         client_info: caseRow.clientInfo,
468:       },
469:       scoringProfile: {
470:         semantic_weight: env.CASE_LINK_WEIGHT_SEMANTIC,
471:         support_weight: env.CASE_LINK_WEIGHT_SUPPORT,
472:         lexical_weight: env.CASE_LINK_WEIGHT_LEXICAL,
473:         category_weight: env.CASE_LINK_WEIGHT_CATEGORY,
474:         strict_min_final_score: env.CASE_LINK_MIN_FINAL_SCORE,
475:         strict_min_pair_score: env.CASE_LINK_MIN_PAIR_SCORE,
476:         strict_min_supporting_matches: env.CASE_LINK_MIN_SUPPORTING_MATCHES,
477:         require_case_support: env.CASE_LINK_REQUIRE_CASE_SUPPORT,
478:       },
479:     });
480:     const matchByRegulationId = new Map(matches.map((match) => [match.regulation_id, match]));
481: 
482:     for (const regulationId of candidateIds) {
483:       const match = matchByRegulationId.get(regulationId);
484:       const breakdown = scoreBreakdownFromMatch(match);
485:       sampleRows.push({
486:         caseId,
487:         regulationId,
488:         label: positives.has(regulationId) ? 1 : 0,
489:         semanticMax: breakdown.semanticMax,
490:         supportCoverage: breakdown.supportCoverage,
491:         lexicalOverlap: breakdown.lexicalOverlap,
492:         categoryPrior: breakdown.categoryPrior,
493:         hasCaseSupport: breakdown.hasCaseSupport,
494:         strongSupportCount: breakdown.strongSupportCount,
495:       });
496:     }
497:   }
498: 
499:   if (!sampleRows.length) {
500:     throw new Error(
501:       "No calibration rows produced. Ensure AI service is running and cases have verified links."
502:     );
503:   }
504: 
505:   const sampledPositivesByCase = new Map<number, Set<number>>();
506:   for (const caseId of sampledCaseIds) {
507:     const positives = positivesByCase.get(caseId);
508:     if (positives && positives.size > 0) {
509:       sampledPositivesByCase.set(caseId, positives);
510:     }
511:   }
512: 
513:   const baselineProfile: ScoringProfile = {
514:     semanticWeight: env.CASE_LINK_WEIGHT_SEMANTIC,
515:     supportWeight: env.CASE_LINK_WEIGHT_SUPPORT,
516:     lexicalWeight: env.CASE_LINK_WEIGHT_LEXICAL,
517:     categoryWeight: env.CASE_LINK_WEIGHT_CATEGORY,
518:     strictMinFinalScore: env.CASE_LINK_MIN_FINAL_SCORE,
519:     strictMinSupportingMatches: env.CASE_LINK_MIN_SUPPORTING_MATCHES,
520:     requireCaseSupport: env.CASE_LINK_REQUIRE_CASE_SUPPORT,
521:   };
522:   const baselineMetrics = evaluateProfile(
523:     sampleRows,
524:     sampledPositivesByCase,
525:     baselineProfile
526:   );
527: 
528:   const profiles = buildCandidateProfiles();
529:   let bestProfile: ScoringProfile | null = null;
530:   let bestMetrics: EvaluationMetrics | null = null;
531: 
532:   for (const profile of profiles) {
533:     const metrics = evaluateProfile(sampleRows, sampledPositivesByCase, profile);
534: 
535:     const candidatePassesRecall = metrics.recall >= minRecallTarget;
536:     const currentPassesRecall =
537:       (bestMetrics?.recall ?? 0) >= minRecallTarget;
538: 
539:     const shouldReplace =
540:       !bestMetrics ||
541:       (candidatePassesRecall && !currentPassesRecall) ||
542:       (candidatePassesRecall === currentPassesRecall &&
543:         (metrics.precision > bestMetrics.precision ||
544:           (metrics.precision === bestMetrics.precision &&
545:             (metrics.f1 > bestMetrics.f1 ||
546:               (metrics.f1 === bestMetrics.f1 &&
547:                 metrics.caseHitRate > bestMetrics.caseHitRate)))));
548: 
549:     if (shouldReplace) {
550:       bestProfile = profile;
551:       bestMetrics = metrics;
552:     }
553:   }
554: 
555:   if (!bestProfile || !bestMetrics) {
556:     throw new Error("Failed to find a candidate scoring profile");
557:   }
558: 
559:   const normalizedBestWeights = normalizeWeights(bestProfile);
560:   const report = {
561:     generatedAt: new Date().toISOString(),
562:     sample: {
563:       rows: sampleRows.length,
564:       cases: sampledPositivesByCase.size,
565:       positives: sampleRows.filter((row) => row.label === 1).length,
566:       negatives: sampleRows.filter((row) => row.label === 0).length,
567:       maxCases,
568:       negativesPerCase,
569:       minRecallTarget,
570:       seed,
571:     },
572:     baseline: {
573:       profile: baselineProfile,
574:       metrics: baselineMetrics,
575:     },
576:     recommended: {
577:       profile: {
578:         ...bestProfile,
579:         ...normalizedBestWeights,
580:       },
581:       metrics: bestMetrics,
582:       env: {
583:         CASE_LINK_WEIGHT_SEMANTIC: Number(
584:           normalizedBestWeights.semanticWeight.toFixed(4)
585:         ),
586:         CASE_LINK_WEIGHT_SUPPORT: Number(
587:           normalizedBestWeights.supportWeight.toFixed(4)
588:         ),
589:         CASE_LINK_WEIGHT_LEXICAL: Number(
590:           normalizedBestWeights.lexicalWeight.toFixed(4)
591:         ),
592:         CASE_LINK_WEIGHT_CATEGORY: Number(
593:           normalizedBestWeights.categoryWeight.toFixed(4)
594:         ),
595:         CASE_LINK_MIN_FINAL_SCORE: bestProfile.strictMinFinalScore,
596:         CASE_LINK_MIN_SUPPORTING_MATCHES: bestProfile.strictMinSupportingMatches,
597:         CASE_LINK_REQUIRE_CASE_SUPPORT: bestProfile.requireCaseSupport,
598:       },
599:     },
600:     notes: [
601:       "Run this on production-like verified links for best signal quality.",
602:       "This calibration optimizes precision while enforcing a minimum recall floor.",
603:       "CASE_LINK_MIN_PAIR_SCORE remains unchanged; tune it separately if needed.",
604:     ],
605:   };
606: 
607:   mkdirSync(dirname(outPath), { recursive: true });
608:   writeFileSync(outPath, JSON.stringify(report, null, 2));
609: 
610:   logger.info(
611:     {
612:       outPath,
613:       sampleRows: report.sample.rows,
614:       cases: report.sample.cases,
615:       baselinePrecision: baselineMetrics.precision,
616:       tunedPrecision: bestMetrics.precision,
617:       baselineRecall: baselineMetrics.recall,
618:       tunedRecall: bestMetrics.recall,
619:       recommended: report.recommended.env,
620:     },
621:     "Case-link scoring calibration completed"
622:   );
623: 
624:   // Also print directly for easy copy in terminal logs.
625:   // eslint-disable-next-line no-console
626:   console.log("\nRecommended env overrides:");
627:   for (const [key, value] of Object.entries(report.recommended.env)) {
628:     // eslint-disable-next-line no-console
629:     console.log(`${key}=${value}`);
630:   }
631:   // eslint-disable-next-line no-console
632:   console.log(`\nDetailed report: ${outPath}`);
633: }
634: 
635: run()
636:   .then(() => process.exit(0))
637:   .catch((error) => {
638:     logger.error({ err: error }, "Case-link scoring calibration failed");
639:     process.exit(1);
640:   });

(End of file - total 640 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/embeddings.py"
}
```

**Output:**
```
<path>/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/core/embeddings.py</path>
<type>file</type>
<content>1: from __future__ import annotations
2: 
3: import math
4: from typing import List, Sequence
5: 
6: from app.config import settings
7: 
8: try:
9:     # Only needed when using the real BGE model
10:     from sentence_transformers import SentenceTransformer  # type: ignore
11: except ImportError:
12:     SentenceTransformer = None  # type: ignore
13: 
14: 
15: class EmbeddingService:
16:     """
17:     Embedding wrapper with two modes:
18: 
19:     - provider="fake":
20:         * Very fast, deterministic, 4-dim vectors.
21:         * Used for tests (/embed, /similarity, pytest).
22: 
23:     - provider="bge":
24:         * Uses BAAI/bge-m3 via sentence-transformers.
25:         * Used in experiments (eval_bge_m3, eval_alarb_*).
26:     """
27: 
28:     def __init__(
29:         self,
30:         provider: str | None = None,
31:         model_name: str | None = None,
32:         device: str | None = None,
33:     ) -> None:
34:         # Decide provider from config or explicit override
35:         self.provider = (provider or settings.embeddings_provider).lower()
36:         self.model = None
37: 
38:         if self.provider == "bge":
39:             if SentenceTransformer is None:
40:                 raise ImportError(
41:                     "sentence-transformers is required for provider='bge'. "
42:                     "Install it with `pip install sentence-transformers`."
43:                 )
44:             name = model_name or settings.embedding_model_name
45:             dev = device or settings.embedding_device
46:             self.model = SentenceTransformer(name, device=dev)
47:         else:
48:             # fake provider → no heavy model
49:             self.model = None
50: 
51:     # ---------- internal helpers ---------- #
52: 
53:     @staticmethod
54:     def _normalize_vector(vec: Sequence[float]) -> List[float]:
55:         norm = math.sqrt(sum(x * x for x in vec)) or 1.0
56:         return [float(x / norm) for x in vec]
57: 
58:     def _embed_fake(self, texts: Sequence[str]) -> List[List[float]]:
59:         """
60:         Very simple deterministic embedding:
61: 
62:         4-dim vector per text:
63:           dim 0: 1.0 if "contract"/"عقد" appears
64:           dim 1: 1.0 if "weather"/"طقس" appears
65:           dim 2: 1.0 if "case"/"قضية"/"دعوى" appears
66:           dim 3: scaled text length
67:         """
68:         vectors: List[List[float]] = []
69: 
70:         for text in texts:
71:             t = text.lower()
72: 
73:             c_contract = 1.0 if ("contract" in t or "عقد" in t) else 0.0
74:             c_weather = 1.0 if ("weather" in t or "طقس" in t) else 0.0
75:             c_case = 1.0 if ("case" in t or "قضية" in t or "دعوى" in t) else 0.0
76:             length_feat = min(len(text) / 100.0, 10.0)
77: 
78:             vectors.append([c_contract, c_weather, c_case, length_feat])
79: 
80:         return vectors
81: 
82:     # ---------- public API ---------- #
83: 
84:     def embed_documents(
85:         self,
86:         texts: Sequence[str],
87:         normalize: bool | None = None,
88:     ) -> List[List[float]]:
89:         """
90:         Embed a batch of texts.
91: 
92:         normalize:
93:           - True  → L2-normalize each vector
94:           - False → leave as-is
95:           - None  → default:
96:               * provider="bge": normalize=True
97:               * provider="fake": normalize=False
98:         """
99:         if self.provider == "bge":
100:             raw_vectors = self.model.encode(  # type: ignore[union-attr]
101:                 list(texts),
102:                 convert_to_numpy=True,
103:             )
104:             vectors: List[List[float]] = [v.tolist() for v in raw_vectors]
105:         else:
106:             vectors = self._embed_fake(texts)
107: 
108:         if normalize is None:
109:             normalize = (self.provider == "bge")
110: 
111:         if normalize:
112:             vectors = [self._normalize_vector(v) for v in vectors]
113: 
114:         return vectors
115: 
116:     def embed_query(
117:         self,
118:         text: str,
119:         normalize: bool | None = None,
120:     ) -> List[float]:
121:         """Embed a single query string."""
122:         return self.embed_documents([text], normalize=normalize)[0]

(End of file - total 122 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/config.py"
}
```

**Output:**
```
<path>/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/app/config.py</path>
<type>file</type>
<content>1: from pathlib import Path
2: 
3: from pydantic_settings import BaseSettings, SettingsConfigDict
4: from pydantic import Field, field_validator
5: from typing import List, Any
6: import json
7: 
8: # Resolve .env relative to this file: ai_service/app/config.py -> ../../.env
9: _ENV_FILE = Path(__file__).parent.parent.parent / ".env"
10: 
11: 
12: class Settings(BaseSettings):
13:     # Pydantic v2 settings config
14:     model_config = SettingsConfigDict(
15:         env_file=str(_ENV_FILE),
16:         case_sensitive=False,
17:         extra="ignore",
18:     )
19: 
20:     # Embedding backend selection
21:     embeddings_provider: str = Field(
22:         default="fake",  # "fake" for tests, "bge" for real model in future
23:         validation_alias="EMBEDDINGS_PROVIDER",
24:     )
25:     embedding_model_name: str = Field(
26:         default="BAAI/bge-m3",
27:         validation_alias="EMBEDDING_MODEL_NAME",
28:     )
29:     embedding_device: str = Field(
30:         default="cpu",  # later you can try "cuda"
31:         validation_alias="EMBEDDING_DEVICE",
32:     )
33: 
34:     # Basic app info
35:     app_name: str = Field(default="AI Microservice", validation_alias="APP_NAME")
36:     app_version: str = Field(default="0.1.0", validation_alias="APP_VERSION")
37:     env: str = Field(default="development", validation_alias="ENV")
38:     debug: bool = Field(default=True, validation_alias="DEBUG")
39:     log_level: str = Field(default="INFO", validation_alias="LOG_LEVEL")
40: 
41:     # Server bind options
42:     host: str = Field(default="127.0.0.1", validation_alias="HOST")
43:     port: int = Field(default=8000, validation_alias="PORT")
44: 
45:     # CORS
46:     cors_origins: List[str] = Field(
47:         default=["http://localhost:3000", "http://localhost:5173"],
48:         validation_alias="CORS_ORIGINS",
49:     )
50: 
51:     # Backend API integration
52:     backend_api_url: str = Field(
53:         default="https://orca-app-uayze.ondigitalocean.app",
54:         validation_alias="BACKEND_API_URL",
55:     )
56:     backend_api_key: str = Field(
57:         default="",  # Optional API key for backend authentication
58:         validation_alias="BACKEND_API_KEY",
59:     )
60: 
61:     # Regulation extraction / OCR
62:     ocr_primary_provider: str = Field(
63:         default="alapi",
64:         validation_alias="OCR_PRIMARY_PROVIDER",
65:     )
66:     ocr_secondary_provider: str = Field(
67:         default="none",
68:         validation_alias="OCR_SECONDARY_PROVIDER",
69:     )
70:     alapi_base_url: str = Field(
71:         default="https://alapi.deep.sa",
72:         validation_alias="ALAPI_BASE_URL",
73:     )
74:     alapi_api_key: str = Field(
75:         default="",
76:         validation_alias="ALAPI_API_KEY",
77:     )
78:     alapi_ocr_path: str = Field(
79:         default="/ocr",
80:         validation_alias="ALAPI_OCR_PATH",
81:     )
82:     source_whitelist_domains: List[str] = Field(
83:         default=["laws.boe.gov.sa", "laws.moj.gov.sa", "boe.gov.sa", "moj.gov.sa"],
84:         validation_alias="SOURCE_WHITELIST_DOMAINS",
85:     )
86:     extraction_timeout_seconds: float = Field(
87:         default=30.0,
88:         validation_alias="EXTRACTION_TIMEOUT_SECONDS",
89:     )
90:     extraction_max_bytes: int = Field(
91:         default=15_000_000,
92:         validation_alias="EXTRACTION_MAX_BYTES",
93:     )
94:     extraction_max_chars: int = Field(
95:         default=120_000,
96:         validation_alias="EXTRACTION_MAX_CHARS",
97:     )
98:     ocr_min_text_chars: int = Field(
99:         default=400,
100:         validation_alias="OCR_MIN_TEXT_CHARS",
101:     )
102:     ocr_strict_mode: bool = Field(
103:         default=False,
104:         validation_alias="OCR_STRICT_MODE",
105:     )
106:     insights_default_top_k: int = Field(
107:         default=5,
108:         validation_alias="INSIGHTS_DEFAULT_TOP_K",
109:     )
110:     insights_max_source_chars: int = Field(
111:         default=15000,
112:         validation_alias="INSIGHTS_MAX_SOURCE_CHARS",
113:     )
114:     insights_summary_sentences: int = Field(
115:         default=4,
116:         validation_alias="INSIGHTS_SUMMARY_SENTENCES",
117:     )
118:     reg_insights_max_source_chars: int = Field(
119:         default=40000,
120:         validation_alias="REG_INSIGHTS_MAX_SOURCE_CHARS",
121:     )
122:     reg_impact_max_source_chars: int = Field(
123:         default=40000,
124:         validation_alias="REG_IMPACT_MAX_SOURCE_CHARS",
125:     )
126:     llm_provider: str = Field(
127:         default="heuristic",
128:         validation_alias="LLM_PROVIDER",
129:     )
130:     llm_base_url: str = Field(
131:         default="",
132:         validation_alias="LLM_BASE_URL",
133:     )
134:     llm_api_key: str = Field(
135:         default="",
136:         validation_alias="LLM_API_KEY",
137:     )
138:     llm_model: str = Field(
139:         default="",
140:         validation_alias="LLM_MODEL",
141:     )
142:     llm_timeout_seconds: float = Field(
143:         default=30.0,
144:         validation_alias="LLM_TIMEOUT_SECONDS",
145:     )
146: 
147:     # --- Gemini verification pipeline (Phase 1) ---
148:     gemini_api_key: str = Field(
149:         default="",
150:         validation_alias="GEMINI_API_KEY",
151:     )
152:     gemini_model: str = Field(
153:         default="gemini-2.0-flash",
154:         validation_alias="GEMINI_MODEL",
155:     )
156:     gemini_enabled: bool = Field(
157:         default=False,
158:         validation_alias="GEMINI_ENABLED",
159:     )
160:     gemini_timeout_seconds: float = Field(
161:         default=25.0,
162:         validation_alias="GEMINI_TIMEOUT_SECONDS",
163:     )
164:     gemini_top_n_candidates: int = Field(
165:         default=15,
166:         validation_alias="GEMINI_TOP_N_CANDIDATES",
167:     )
168: 
169:     # --- Chunk overlap (Phase 1) ---
170:     chunk_overlap_ratio: float = Field(
171:         default=0.0,
172:         validation_alias="CHUNK_OVERLAP_RATIO",
173:     )
174: 
175:     # --- Instruction-tuned embedding queries (Phase 1) ---
176:     embedding_query_instruction_ar: str = Field(
177:         default="",
178:         validation_alias="EMBEDDING_QUERY_INSTRUCTION_AR",
179:     )
180:     embedding_query_instruction_en: str = Field(
181:         default="",
182:         validation_alias="EMBEDDING_QUERY_INSTRUCTION_EN",
183:     )
184: 
185:     # --- Cross-encoder reranking (Phase 2 — flags only, not yet implemented) ---
186:     cross_encoder_enabled: bool = Field(
187:         default=False,
188:         validation_alias="CROSS_ENCODER_ENABLED",
189:     )
190:     cross_encoder_model_name: str = Field(
191:         default="BAAI/bge-reranker-v2-m3",
192:         validation_alias="CROSS_ENCODER_MODEL_NAME",
193:     )
194:     cross_encoder_top_n: int = Field(
195:         default=15,
196:         validation_alias="CROSS_ENCODER_TOP_N",
197:     )
198: 
199:     # --- HyDE (Phase 2) ---
200:     hyde_enabled: bool = Field(
201:         default=False,
202:         validation_alias="HYDE_ENABLED",
203:     )
204:     hyde_max_query_chars: int = Field(
205:         default=4000,
206:         validation_alias="HYDE_MAX_QUERY_CHARS",
207:     )
208: 
209:     # --- ColBERT / late-interaction reranking (Phase 3 — experimental) ---
210:     colbert_enabled: bool = Field(
211:         default=False,
212:         validation_alias="COLBERT_ENABLED",
213:     )
214:     colbert_top_n: int = Field(
215:         default=15,
216:         validation_alias="COLBERT_TOP_N",
217:     )
218: 
219:     # --- Agentic retrieval (Phase 3 — experimental) ---
220:     agentic_retrieval_enabled: bool = Field(
221:         default=False,
222:         validation_alias="AGENTIC_RETRIEVAL_ENABLED",
223:     )
224:     agentic_max_rounds: int = Field(
225:         default=2,
226:         validation_alias="AGENTIC_MAX_ROUNDS",
227:     )
228:     agentic_min_candidates_for_refinement: int = Field(
229:         default=3,
230:         validation_alias="AGENTIC_MIN_CANDIDATES_FOR_REFINEMENT",
231:     )
232:     agentic_timeout_seconds: float = Field(
233:         default=30.0,
234:         validation_alias="AGENTIC_TIMEOUT_SECONDS",
235:     )
236: 
237:     @field_validator("cors_origins", mode="before")
238:     @classmethod
239:     def parse_cors(cls, v: Any) -> Any:
240:         """
241:         Accept:
242:           - Python list (already parsed)
243:           - JSON array string: '["http://...","http://..."]'
244:           - Comma-separated string: 'http://...,http://...'
245:         """
246:         if isinstance(v, list):
247:             return v
248: 
249:         if isinstance(v, str):
250:             s = v.strip()
251:             if not s:
252:                 return []
253: 
254:             # Try JSON array first
255:             if s.startswith("[") and s.endswith("]"):
256:                 try:
257:                     return json.loads(s)
258:                 except Exception:
259:                     # fall through to comma-split
260:                     pass
261: 
262:             # Fallback: comma-separated
263:             return [item.strip() for item in s.split(",") if item.strip()]
264: 
265:         return v
266: 
267:     @field_validator("source_whitelist_domains", mode="before")
268:     @classmethod
269:     def parse_domains(cls, v: Any) -> Any:
270:         if isinstance(v, list):
271:             return v
272: 
273:         if isinstance(v, str):
274:             s = v.strip()
275:             if not s:
276:                 return []
277: 
278:             if s.startswith("[") and s.endswith("]"):
279:                 try:
280:                     return json.loads(s)
281:                 except Exception:
282:                     pass
283: 
284:             return [item.strip() for item in s.split(",") if item.strip()]
285: 
286:         return v
287: 
288: 
289: # Singleton settings instance
290: settings = Settings()

(End of file - total 290 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/requirements.txt"
}
```

**Error:**
```
Error: File not found: /Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/ai_service/requirements.txt
```

---

## Assistant (Build · gpt-5.3-codex · 5.8s)

_Thinking:_



**Tool: glob**

**Input:**
```json
{
  "pattern": "**/requirements*.txt",
  "path": "/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice"
}
```

**Output:**
```
/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/requirements.txt
```

---

## Assistant (Build · gpt-5.3-codex · 2.9s)

**Tool: read**

**Input:**
```json
{
  "filePath": "/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/requirements.txt"
}
```

**Output:**
```
<path>/Users/salehalobaylan/Desktop/Silah-Legal/Legal-Case-Management-System-AI-Microservice/requirements.txt</path>
<type>file</type>
<content>1: # FastAPI web framework
2: fastapi>=0.111,<1.0
3: 
4: # ASGI server; 
5: uvicorn[standard]>=0.30,<1.0
6: 
7: # Required for file upload / form data support
8: python-multipart>=0.0.9,<1.0
9: 
10: # Typed settings from env/.env
11: pydantic>=2.6,<3.0
12: pydantic-settings>=2.2,<3.0
13: 
14: # Simple structured logging
15: loguru>=0.7,<1.0
16: 
17: # Numpy
18: numpy>=1.26,<3.0
19: 
20: # to run tests
21: pytest>=8.2,<9.0
22: httpx>=0.27,<1.0
23: beautifulsoup4>=4.12,<5.0
24: pypdf>=4.3,<6.0
25: python-docx>=1.1,<2.0
26: 
27: # Excel file support (.xlsx)
28: openpyxl>=3.1,<4.0
29: 
30: # Legacy Excel (.xls) support (optional fallback)
31: xlrd>=2.0,<3.0
32: 
33: # RTF file support (optional)
34: striprtf>=0.0.26,<1.0
35: 
36: # Arabic/RTL PDF extraction via pdfplumber.
37: # pdfplumber provides word-level bounding boxes, enabling position-based
38: # right-to-left word ordering for Arabic PDFs (words stored in visual order
39: # in the content stream). Falls back to pypdf + NFKC normalization.
40: pdfplumber>=0.10,<1.0
41: 
42: # Self-hosted OCR via Tesseract (Arabic + English).
43: # Requires system packages: tesseract, poppler (for pdf2image).
44: # Install Arabic data: download ara.traineddata to tessdata dir.
45: pytesseract>=0.3,<1.0
46: pdf2image>=1.16,<2.0
47: Pillow>=10.0,<13.0
48: 
49: # Back-end 
50: torch>=2.2.0
51: 
52: # Ai model loader
53: sentence-transformers==3.0.1
54: 
55: # Gemini LLM verification (Phase 1)
56: google-generativeai>=0.7,<1.0
57: 

(End of file - total 57 lines)
</content>
```

---

## Assistant (Build · gpt-5.3-codex · 13.1s)

_Thinking:_



Perfect — that means you’re in a very good position.

I checked your code setup, and you already have most prerequisites:

- `Legal-Case-Management-System-AI-Microservice/requirements.txt` already has `torch` + `sentence-transformers`.
- `Legal-Case-Management-System-AI-Microservice/ai_service/app/core/embeddings.py` already loads `SentenceTransformer(...)`.
- `Legal-Case-Management-System-AI-Microservice/ai_service/app/config.py` already supports `EMBEDDINGS_PROVIDER` and `EMBEDDING_MODEL_NAME`.
- `Legal-Case-Management-System/src/scripts/tune-case-link-scoring.ts` already reads verified case-regulation links and can be reused for export logic.

So yes: with your normalized regulations DB + workers, this can work.

What’s still needed (only 3 pieces):
- Build/export training dataset (triplets):  
  `case_text`, `positive_article_text`, `negative_article_text`
- Run fine-tuning script for BGE-M3 on GPU.
- Point model path in env:  
  `EMBEDDINGS_PROVIDER=bge`  
  `EMBEDDING_MODEL_NAME=/path/to/fine-tuned-model`

So if you provide case texts (or let workers fetch them), I can do the rest of the pipeline end-to-end.

---

## User

how can i get postive regulation and negative regulation? should i get one example or each case has to provide it for it?

---

## Assistant (Build · gpt-5.3-codex · 7.9s)

_Thinking:_



Great question.  
For your use case, **each training case should have a positive**. Negatives can be generated.

- **Positive regulation** = the correct article/regulation for that case.
  - Source options:
    - your verified lawyer links in DB (best)
    - citation extracted from judgment text (`المادة ... من نظام ...`) and mapped to article text
- **Negative regulation** = wrong but similar article.
  - You usually **don’t label manually**; generate automatically:
    1. retrieve top-20 with current model
    2. remove positives
    3. keep top 1–3 as hard negatives

Do you need positive+negative for every case?
- **Positive: yes, ideally per case** (at least 1).
- **Negative: can be auto-generated per case** (1–5 recommended).

Minimum practical format per case:
```json
{"query":"case text","positive":"correct article","negative":"hard wrong article"}
```

So: you should collect/derive positives per case; negatives are mostly automatic.

---

## User

ok so positive is extracted from the description, so i give a case id and case description then the pipeline extract regulations from it then normalize the data the we train the model on them right?

---

## Assistant (Build · gpt-5.3-codex · 6.8s)

_Thinking:_



Yes, that’s the right idea — with one important tweak:

- `case_id + case_description` → extract cited regulations/articles
- map citations to your normalized regulation articles
- build training rows
- generate hard negatives
- train model

Important tweak:
- Extracted citations are **weak positives** (usually good, not always perfect), so add a quick quality check:
  - manually review ~200 sampled rows before full training.

So final flow:

1. Ingest `case_id`, `case_text`.
2. Extract `المادة X من نظام Y`.
3. Resolve to canonical article text in DB (positive).
4. Retrieve similar-but-wrong articles (negatives).
5. Build triplets and train.
6. Evaluate vs baseline, then deploy.

So yes — your plan is correct.

---

## User

ok please check if there is an api for extracting the cases data because i think when we extracted regulation data there were an api or a simple way that MOJ provided it to extract the regulations so check please if there is a way to extract cases like these in here in the same way we extracted the regulations: https://laws.moj.gov.sa/ar/JudicialDecisionsList/1

---

## Assistant (Build · gpt-5.3-codex · 11.1s)

_Thinking:_



**Tool: bash**

**Input:**
```json
{
  "command": "python3 - <<'PY'\nimport re, json, urllib.request\nfrom urllib.parse import urljoin\nurl='https://laws.moj.gov.sa/ar/JudicialDecisionsList/1'\nhtml=urllib.request.urlopen(url, timeout=30).read().decode('utf-8','ignore')\njs_paths=re.findall(r'<script[^>]+src=\"([^\"]+)\"', html)\njs_urls=[urljoin(url,p) for p in js_paths]\nprint('JS files:', len(js_urls))\nfor u in js_urls:\n    print(u)\n\npatterns=[r'https?://[^\"\\'\\s]+', r'/[A-Za-z0-9_\\-/]*(?:api|Api|API)[A-Za-z0-9_\\-/]*', r'Judicial[^\"\\'\\s]*', r'Decision[^\"\\'\\s]*']\nseen=set()\nfor u in js_urls:\n    try:\n        txt=urllib.request.urlopen(u, timeout=40).read().decode('utf-8','ignore')\n    except Exception as e:\n        print('ERR',u,e)\n        continue\n    hits=[]\n    for p in patterns:\n        hits.extend(re.findall(p, txt))\n    # keep unique short list\n    clean=[]\n    for h in hits:\n        if h not in seen:\n            seen.add(h)\n            clean.append(h)\n    if clean:\n        print('\\n--- hits from',u)\n        for h in clean[:80]:\n            print(h)\nprint('\\nTotal unique hits:',len(seen))\nPY",
  "description": "Scan MOJ Nuxt JS for possible API endpoints",
  "timeout": 120000
}
```

**Output:**
```
JS files: 4
https://laws.moj.gov.sa/_nuxt/1d1c1f4.js
https://laws.moj.gov.sa/_nuxt/45878cb.js
https://laws.moj.gov.sa/_nuxt/95549fd.js
https://laws.moj.gov.sa/_nuxt/f7bb847.js

--- hits from https://laws.moj.gov.sa/_nuxt/45878cb.js
http://www.w3.org/1999/xlink
http://www.w3.org/2000/svg
http://www.w3.org/1998/Math/MathML
https://github.com/zloirock/core-js/blob/v3.39.0/LICENSE
https://github.com/zloirock/core-js
https://a
https://a/c%20d?a=1&c=3
https://a@b
https://тест
https://a#б
https://x
https://github.com/axios/axios.git
https://github.com/axios/axios/issues
https://axios-http.com

--- hits from https://laws.moj.gov.sa/_nuxt/95549fd.js
http://momentjs.com/guides/#/warnings/define-locale/
http://momentjs.com/guides/#/warnings/js-date/
http://momentjs.com/guides/#/warnings/min-max/
http://momentjs.com/guides/#/warnings/add-inverted-param/
http://momentjs.com/guides/#/warnings/zone/
http://momentjs.com/guides/#/warnings/dst-shifted/
https://laws-gateway.moj.gov.sa/apis/legislations/v1
https://laws-gateway.moj.gov.sa/selfservices/apis/legislations/v1
https://laws.moj.gov.sa
https://www.google.com/recaptcha/api.js?render=
https://nuxtjs.org
https://bootstrap-vue.org/docs#using-module-bundlers
https://bit.ly/2ZqJzkp
https://example.com
http://cang.baidu.com/do/add?iu=@u&it=@t
https://bufferapp.com/add?text=@t&url=@u
https://www.evernote.com/clip.action?url=@u&title=@t
https://www.facebook.com/sharer/sharer.php?u=@u&title=@t&description=@d&quote=@q&hashtag=@h
https://share.flipboard.com/bookmarklet/popout?v=2&url=@u&title=@t
https://news.ycombinator.com/submitlink?u=@u&t=@t
http://www.instapaper.com/edit?url=@u&title=@t&description=@d
http://line.me/R/msg/text/?@t%0D%0A@u%0D%0A@d
https://www.linkedin.com/sharing/share-offsite/?url=@u
https://connect.ok.ru/dk?st.cmd=WidgetSharePreview&st.shareUrl=@u&st.comments=@t
https://pinterest.com/pin/create/button/?url=@u&media=@m&description=@t
https://getpocket.com/save?url=@u&title=@t
https://www.quora.com/share?url=@u&title=@t
https://www.reddit.com/submit?url=@u&title=@t
https://web.skype.com/share?url=@t%0D%0A@u%0D%0A@d
https://www.stumbleupon.com/submit?url=@u&title=@t
https://t.me/share/url?url=@u&text=@t%0D%0A@d
https://www.tumblr.com/share/link?url=@u&name=@t&description=@d
https://twitter.com/intent/tweet?text=@t&url=@u&hashtags=@h@tu
https://vk.com/share.php?url=@u&title=@t&description=@d&image=@m&noparse=true
http://service.weibo.com/share/share.php?url=@u&title=@t&pic=@m
https://api.whatsapp.com/send?text=@t%0D%0A@u%0D%0A@d
https://wordpress.com/press-this.php?u=@u&t=@t&s=@d&i=@m
https://www.xing.com/social/share/spi?op=share&url=@u&title=@t
https://www.yammer.com/messages/new?login=true&status=@t%0D%0A@u%0D%0A@d
https://github.com/mathiasbynens/CSS.escape).
/apis/legislations/v1
/selfservices/apis/legislations/v1
/recaptcha/api
//api
JudicialDecisions
JudicialDecisionsShare
JudicialDecisionsHomeSearch
Judicial-decisions/components/Judicial-decisions-cards
Judicial-decisions-components-Judicial-decisions-cards
Judicial-decisions/components/Judicial-decisions-list
Judicial-decisions-components-Judicial-decisions-list
Judicial-decisions-components-Judicial-decisions-cards___ar
Judicial-decisions-components-Judicial-decisions-list___ar
Judicial-decisions-components-Judicial-decisions-cards___en
Judicial-decisions-components-Judicial-decisions-list___en
JudicialDecisionsList/:courtTypes
JudicialDecisionsList-courtTypes___ar
JudicialDecisionsList-courtTypes___en
JudicialDecisionsList/:courtTypes?/Judicial-DecisionsList-search
JudicialDecisionsList-courtTypes-Judicial-DecisionsList-search___ar
JudicialDecisionsList/:courtTypes?/modal
JudicialDecisionsList-courtTypes-modal___ar
JudicialDecisionsList-courtTypes-Judicial-DecisionsList-search___en
JudicialDecisionsList-courtTypes-modal___en
JudicialDecisionsList/:courtTypes?/:id
JudicialDecisionsList-courtTypes-id___ar
JudicialDecisionsList-courtTypes-id___en
JudicialDecisionsList-courtTypes
JudicialDecisionsList-courtTypes-Judicial-DecisionsList-search
JudicialDecisionsList-courtTypes-modal
JudicialDecisionsList-courtTypes-id
Decisions
DecisionsShare
DecisionsHomeSearch
DecisionsList/:courtTypes
DecisionsList-courtTypes___ar
DecisionsList-courtTypes___en
DecisionsList/:courtTypes?/Judicial-DecisionsList-search
DecisionsList-courtTypes-Judicial-DecisionsList-search___ar
DecisionsList/:courtTypes?/modal

--- hits from https://laws.moj.gov.sa/_nuxt/f7bb847.js
https://static.hotjar.com/c/hotjar-
https://www.snapchat.com/add/mojksa
https://www.facebook.com/SaudiMoj/
https://www.instagram.com/mojksa/
https://www.youtube.com/user/ksamoj
https://twitter.com/mojksa
https://play.google.com/store/apps/details?id=com.moj.najiz
https://apps.apple.com/ca/app/najiz-%D9%86%D8%A7%D8%AC%D8%B2/id1524792474
http://jigsaw.w3.org/css-validator/validator?uri=https://www.moj.gov.sa/ar/pages/default.aspx
https://raqmi.dga.gov.sa/platforms/platforms/98887777-b59d-443c-ab16-8222cf955bb5/platform-license
https://www.moj.gov.sa/ar/Ministry/Pages/AboutUs.aspx
https://www.moj.gov.sa/ar/Ministry/Pages/informationSecurityStrategy.aspx
https://www.moj.gov.sa/ar/MediaCenter/News/Pages/default.aspx
https://www.moj.gov.sa/ar/Ministry/Pages/Newsletters.aspx
https://www.moj.gov.sa/ar/Ministry/Pages/sla.aspx
https://www.moj.gov.sa/ar/Ministry/Pages/Accessibility.aspx
https://www.moj.gov.sa/ar/Ministry/Pages/ContactUs.aspx
https://www.moj.gov.sa/ar/Ministry/eParticipation/Pages/default.aspx
https://www.moj.gov.sa/ar/Ministry/Pages/NajizInquiries.aspx
https://my.gov.sa/ar/content/report-corruption#section-1
https://www.moj.gov.sa/ar/Ministry/Pages/Info-Rights.aspx
https://www.moj.gov.sa/ar/Ministry/Pages/FAQ.aspx
https://www.scj.gov.sa/
https://my.gov.sa/ar
https://od.data.gov.sa/ar/home
https://eparticipation.my.gov.sa/
https://istitlaa.ncc.gov.sa/ar/Pages/default.aspx
https://new.najiz.sa/applications/video-chat
https://najiz.sa/applications/landing
https://www.moj.gov.sa/ar/Ministry/Pages/PrivacyPolicy.aspx
https://www.moj.gov.sa/ar/Ministry/Pages/TermsOfUse.aspx
https://www.moj.gov.sa/ar/Pages/SiteMap.aspx
Judicial
JudicialTerms
JudicialDecisionsList/1
DecisionsSummary
Decision
DecisionsList/1

Total unique hits: 142

```

---

## Assistant (Build · gpt-5.3-codex · 8.0s)

_Thinking:_



**Tool: bash**

**Input:**
```json
{
  "command": "python3 - <<'PY'\nimport re, urllib.request\nu='https://laws.moj.gov.sa/_nuxt/95549fd.js'\njs=urllib.request.urlopen(u, timeout=60).read().decode('utf-8','ignore')\nfor kw in ['laws-gateway.moj.gov.sa','JudicialDecisions','DecisionsList','apis/','selfservices/apis']:\n    print('\\n====',kw)\n    for m in re.finditer(re.escape(kw), js):\n        s=max(0,m.start()-180); e=min(len(js), m.end()+220)\n        snippet=js[s:e]\n        snippet=snippet.replace('\\n',' ')\n        print(snippet[:380])\n        break\nPY",
  "description": "Inspect Nuxt bundle snippets around API-related keywords",
  "timeout": 120000
}
```

**Output:**
```

==== laws-gateway.moj.gov.sa
case 0:return e.context||(e.context={isStatic:!0,isDev:!1,isHMR:!1,app:e,store:e.store,payload:n.payload,error:n.error,base:e.router.options.base,env:{NUXT_APP_PORTAL_URL:"https://laws-gateway.moj.gov.sa/apis/legislations/v1",BASE_API_URL:"https://laws-gateway.moj.gov.sa/apis/legislations/v1",BASE_AUTH_API_URL:"https://laws-gateway.moj.gov.sa/selfservices/apis/legislations/v1",

==== JudicialDecisions
(){return R})),n.d(r,"SuggestionAdvancedSearch",(function(){return I})),n.d(r,"SuggestionHea",(function(){return B})),n.d(r,"SuggestionSugglist",(function(){return N})),n.d(r,"HomeJudicialDecisions",(function(){return W})),n.d(r,"HomeJudicialDecisionsShare",(function(){return z})),n.d(r,"HomeJudicialDecisionsHomeSearch",(function(){return V})),n.d(r,"HomeAdvancedSearch",(functi

==== DecisionsList
decisions/components/Judicial-decisions-list",component:T,name:"Judicial-decisions-components-Judicial-decisions-list___en"},{path:"/",component:m,name:"index"},{path:"/ar/JudicialDecisionsList/:courtTypes",component:Y,name:"JudicialDecisionsList-courtTypes___ar"},{path:"/ar/legislation/:id?",component:S,name:"legislation-id___ar"},{path:"/en/JudicialDecisionsList/:courtTypes",

==== apis/
|(e.context={isStatic:!0,isDev:!1,isHMR:!1,app:e,store:e.store,payload:n.payload,error:n.error,base:e.router.options.base,env:{NUXT_APP_PORTAL_URL:"https://laws-gateway.moj.gov.sa/apis/legislations/v1",BASE_API_URL:"https://laws-gateway.moj.gov.sa/apis/legislations/v1",BASE_AUTH_API_URL:"https://laws-gateway.moj.gov.sa/selfservices/apis/legislations/v1",SHOW_ENGLISH_PDF:"0",APP

==== selfservices/apis
L_URL:"https://laws-gateway.moj.gov.sa/apis/legislations/v1",BASE_API_URL:"https://laws-gateway.moj.gov.sa/apis/legislations/v1",BASE_AUTH_API_URL:"https://laws-gateway.moj.gov.sa/selfservices/apis/legislations/v1",SHOW_ENGLISH_PDF:"0",APP_ENV:"Production",CONTACT_US_EMAIL:"rc@moj.gov.sa",HIDE_BEFORE_PRODUCTION:"0",HOTJAR_KEY:"5080101",FRONT_BASE_URL:"https://laws.moj.gov.sa"}}

```

---

## Assistant (Build · gpt-5.3-codex · 6.2s)

**Tool: bash**

**Input:**
```json
{
  "command": "python3 - <<'PY'\nimport urllib.request, json\nbase='https://laws-gateway.moj.gov.sa/apis/legislations/v1'\npaths=[\n '/JudicialDecisionsList/1',\n '/JudicialDecisions/1',\n '/DecisionsList/1',\n '/Decisions/1',\n '/judicial-decisions',\n '/JudicialDecisions',\n '/JudicialDecisions?courtTypes=1&page=1',\n '/JudicialDecisionsList?courtTypes=1&page=1',\n '/HomeJudicialDecisions',\n '/DecisionsSummary',\n '/Decision',\n '/Search/JudicialDecisions'\n]\nfor p in paths:\n    url=base+p\n    req=urllib.request.Request(url, headers={'Accept':'application/json'})\n    try:\n        with urllib.request.urlopen(req, timeout=25) as r:\n            data=r.read(400)\n            print('OK', url, 'status', r.status, 'sample', data[:120])\n    except Exception as e:\n        print('ERR', url, e)\nPY",
  "description": "Probe likely laws-gateway judicial decisions API endpoints",
  "timeout": 120000
}
```

**Output:**
```
ERR https://laws-gateway.moj.gov.sa/apis/legislations/v1/JudicialDecisionsList/1 HTTP Error 404: Resource Not Avialable
ERR https://laws-gateway.moj.gov.sa/apis/legislations/v1/JudicialDecisions/1 HTTP Error 404: Resource Not Avialable
ERR https://laws-gateway.moj.gov.sa/apis/legislations/v1/DecisionsList/1 HTTP Error 404: Resource Not Avialable
ERR https://laws-gateway.moj.gov.sa/apis/legislations/v1/Decisions/1 HTTP Error 404: Resource Not Avialable
ERR https://laws-gateway.moj.gov.sa/apis/legislations/v1/judicial-decisions HTTP Error 404: Resource Not Avialable
ERR https://laws-gateway.moj.gov.sa/apis/legislations/v1/JudicialDecisions HTTP Error 404: Resource Not Avialable
ERR https://laws-gateway.moj.gov.sa/apis/legislations/v1/JudicialDecisions?courtTypes=1&page=1 HTTP Error 404: Resource Not Avialable
ERR https://laws-gateway.moj.gov.sa/apis/legislations/v1/JudicialDecisionsList?courtTypes=1&page=1 HTTP Error 404: Resource Not Avialable
ERR https://laws-gateway.moj.gov.sa/apis/legislations/v1/HomeJudicialDecisions HTTP Error 404: Resource Not Avialable
ERR https://laws-gateway.moj.gov.sa/apis/legislations/v1/DecisionsSummary HTTP Error 404: Resource Not Avialable
ERR https://laws-gateway.moj.gov.sa/apis/legislations/v1/Decision HTTP Error 404: Resource Not Avialable
ERR https://laws-gateway.moj.gov.sa/apis/legislations/v1/Search/JudicialDecisions HTTP Error 404: Resource Not Avialable

```

---

## Assistant (Build · gpt-5.3-codex · 7.2s)

**Tool: bash**

**Input:**
```json
{
  "command": "python3 - <<'PY'\nimport re, urllib.request\njs=urllib.request.urlopen('https://laws.moj.gov.sa/_nuxt/95549fd.js', timeout=60).read().decode('utf-8','ignore')\n# print lines/fragments around '/apis/legislations/v1'\nfor m in re.finditer(r'/apis/legislations/v1[^\"\\']*', js):\n    s=max(0,m.start()-120); e=min(len(js),m.end()+200)\n    print(js[s:e].replace('\\n',' ')[:500])\n    print('---')\n    break\n# try to extract axios url literals with '/api/' etc\ncands=set(re.findall(r'\"(/[^\"\\\\]*(?:api|judicial|decision|search)[^\"\\\\]*)\"', js, flags=re.I))\nprint('cand count',len(cands))\nfor c in sorted(list(cands))[:120]:\n    print(c)\nPY",
  "description": "Extract candidate API path literals from bundle JS",
  "timeout": 120000
}
```

**Output:**
```
ore,payload:n.payload,error:n.error,base:e.router.options.base,env:{NUXT_APP_PORTAL_URL:"https://laws-gateway.moj.gov.sa/apis/legislations/v1",BASE_API_URL:"https://laws-gateway.moj.gov.sa/apis/legislations/v1",BASE_AUTH_API_URL:"https://laws-gateway.moj.gov.sa/selfservices/apis/legislations/v1",SHOW_ENGLISH_PDF:"0",APP_ENV:"Production",CO
---
cand count 18
/Judicial-decisions/components/Judicial-decisions-cards
/Judicial-decisions/components/Judicial-decisions-list
/JudicialDecisionsList/:courtTypes
/JudicialDecisionsList/:courtTypes?/:id
/JudicialDecisionsList/:courtTypes?/Judicial-DecisionsList-search
/JudicialDecisionsList/:courtTypes?/modal
/ar/Judicial-decisions/components/Judicial-decisions-cards
/ar/Judicial-decisions/components/Judicial-decisions-list
/ar/JudicialDecisionsList/:courtTypes
/ar/JudicialDecisionsList/:courtTypes?/:id
/ar/JudicialDecisionsList/:courtTypes?/Judicial-DecisionsList-search
/ar/JudicialDecisionsList/:courtTypes?/modal
/en/Judicial-decisions/components/Judicial-decisions-cards
/en/Judicial-decisions/components/Judicial-decisions-list
/en/JudicialDecisionsList/:courtTypes
/en/JudicialDecisionsList/:courtTypes?/:id
/en/JudicialDecisionsList/:courtTypes?/Judicial-DecisionsList-search
/en/JudicialDecisionsList/:courtTypes?/modal

```

---

## Assistant (Build · gpt-5.3-codex · 8.2s)

**Tool: bash**

**Input:**
```json
{
  "command": "python3 - <<'PY'\nimport urllib.request\nurl='https://laws.moj.gov.sa/ar/JudicialDecisionsList/1'\nhtml=urllib.request.urlopen(url, timeout=30).read().decode('utf-8','ignore')\nfor key in ['__NUXT__','window.__NUXT__','BASE_API_URL','laws-gateway']:\n    i=html.find(key)\n    print(key, i)\nif 'window.__NUXT__' in html:\n    i=html.find('window.__NUXT__')\n    print('\\n', html[i:i+1200])\nPY",
  "description": "Inspect initial HTML for embedded API config values"
}
```

**Output:**
```
__NUXT__ 2551
window.__NUXT__ 2544
BASE_API_URL -1
laws-gateway -1

 window.__NUXT__={config:{BASE_URL:"https://laws.moj.gov.sa",APP_ENV:"Production",HOTJAR_KEY:5080101,_app:{basePath:"/",assetsPath:"/_nuxt/",cdnURL:null}}}</script>
  <script src="/_nuxt/1d1c1f4.js"></script><script src="/_nuxt/45878cb.js"></script><script src="/_nuxt/95549fd.js"></script><script src="/_nuxt/f7bb847.js"></script></body>
</html>


```

---

## Assistant (Build · gpt-5.3-codex · 11.8s)

_Thinking:_



Yes — I checked it.

What I found:
- The page is a Nuxt frontend (JS app), and it references an API gateway:
  - `https://laws-gateway.moj.gov.sa/apis/legislations/v1`
- It clearly has judicial decisions routes in frontend code (`JudicialDecisionsList`, details page, search).
- But direct guessing of endpoints returns `404 Resource Not Avialable`, so the exact endpoints are likely:
  - different path names, and/or
  - require request headers/cookies/token from browser session.

So: **there is likely an API behind it, but it is not openly documented like the regulation endpoint you used before.**

Fastest way to confirm exact endpoints:
- Open `https://laws.moj.gov.sa/ar/JudicialDecisionsList/1` in browser.
- DevTools -> Network -> filter `fetch/XHR`.
- Click pagination + open one decision.
- Copy the request as cURL.
- Then we can automate from that exact cURL pattern.

If you share one HAR file or one copied cURL from Network tab, I can immediately tell you:
- which endpoint is list vs detail,
- how to paginate,
- and how to build a safe extractor pipeline.

---

## User

there is Request URL
https://laws-gateway.moj.gov.sa/apis/legislations/v1/Judgements/judgements-list
Request Method
POST
Status Code
200 OK
Remote Address
87.101.236.244:443
Referrer Policy
strict-origin-when-cross-origin {
    "statusCode": 200,
    "success": true,
    "message": "تم إتمام العملية بنجاح",
    "model": {
        "judgementsCollection": [
            {
                "id": "5lA5EyMEfqij2_JGH-PUxovza30RJX-gDPmVpPq-RuqqXn82gTJ9-AUy7vtdtm8Z",
                "judgementNumber": "4630103285",
                "judgementDate": "1446-12-04",
                "city": "بريدة",
                "hijriYear": 1446,
                "courtName": "المحكمة التجارية",
                "courtType": 1,
                "caseNumber": "4630103285",
                "isAppeal": false,
                "refereeNo": null,
                "mostView": false,
                "isFavorite": false
            },
            {
                "id": "e1Ya-Ng6UTKUrnvf8cXTRY8Yc15zSTu1UzhFWhQMh1n9N6-lJkUfpjhM-treE3pz",
                "judgementNumber": "4531025219",
                "judgementDate": "1446-10-30",
                "city": "الدمام",
                "hijriYear": 1446,
                "courtName": "المحكمة التجارية",
                "courtType": 1,
                "caseNumber": "4531025219",
                "isAppeal": false,
                "refereeNo": null,
                "mostView": false,
                "isFavorite": false
            },
            {
                "id": "VZD_3eYPB2NQeiZeFEokTmQ93zwFQmMmwoge3s0XHfw3mECCTcdiDcoaYsCGoEyt",
                "judgementNumber": "4530998498",
                "judgementDate": "1446-10-30",
                "city": "الرياض",
                "hijriYear": 1446,
                "courtName": "المحكمة التجارية",
                "courtType": 1,
                "caseNumber": "4530998498",
                "isAppeal": false,
                "refereeNo": null,
                "mostView": false,
                "isFavorite": false
            },
            {
                "id": "zuHMQSS-SDsYwUBrP2WMPSNb0af5UxBTGZuQTtm1eIJUIps7iyPR5RM167JIfvzg",
                "judgementNumber": "4630819296",
                "judgementDate": "1446-09-19",
                "city": "الدمام",
                "hijriYear": 1446,
                "courtName": "المحكمة التجارية",
                "courtType": 1,
                "caseNumber": "4630819296",
                "isAppeal": false,
                "refereeNo": null,
                "mostView": false,
                "isFavorite": false
            },
            {
                "id": "tHmWFpfqu2BzzaDB9cFx36ET7Yuocyka9OFhNdoiqLGxJ82QICUjU2-Co2EdTa3o",
                "judgementNumber": "4630220365",
                "judgementDate": "1446-09-06",
                "city": "الدمام",
                "hijriYear": 1446,
                "courtName": "المحكمة التجارية",
                "courtType": 1,
                "caseNumber": "4630220365",
                "isAppeal": false,
                "refereeNo": null,
                "mostView": false,
                "isFavorite": false
            },
            {
                "id": "ZSLzkhtCKP0JESRLDJbAPGiq-af4hLGwPdGDeySd72iOm6idjl7g3SLz7pj-6dUI",
                "judgementNumber": "4630796711",
                "judgementDate": "1446-08-28",
                "city": "الدمام",
                "hijriYear": 1446,
                "courtName": "المحكمة التجارية",
                "courtType": 1,
                "caseNumber": "4630796711",
                "isAppeal": false,
                "refereeNo": null,
                "mostView": false,
                "isFavorite": false
            },
            {
                "id": "HQXu9l27zfwhf4ThfHx3aXAYP2FebAhww7vSX_wP5cLgduZXPd85NgllKpjYhsOU",
                "judgementNumber": "4630558375",
                "judgementDate": "1446-07-12",
                "city": "أبها",
                "hijriYear": 1446,
                "courtName": "المحكمة التجارية",
                "courtType": 1,
                "caseNumber": "4630558375",
                "isAppeal": false,
                "refereeNo": null,
                "mostView": false,
                "isFavorite": false
            },
            {
                "id": "XlIbil8EMzQRbiaOAK2kZlQ2irCJ4f-GaLSWwrjdar5oiDeSqVn7ExcK95gByII1",
                "judgementNumber": "4630489899",
                "judgementDate": "1446-06-14",
                "city": "الرياض",
                "hijriYear": 1446,
                "courtName": "المحكمة التجارية",
                "courtType": 1,
                "caseNumber": "4630489899",
                "isAppeal": false,
                "refereeNo": null,
                "mostView": false,
                "isFavorite": false
            },
            {
                "id": "0w4IlPsdu-UmnsXlM_0zxXy3DYFxjBWew4TE4nfhpwBHyrW6ucgprmYPFXMlT8eZ",
                "judgementNumber": "4630316927",
                "judgementDate": "1446-06-11",
                "city": "الرياض",
                "hijriYear": 1446,
                "courtName": "المحكمة التجارية",
                "courtType": 1,
                "caseNumber": "4630316927",
                "isAppeal": false,
                "refereeNo": null,
                "mostView": false,
                "isFavorite": false
            },
            {
                "id": "c4MF73qhYbG1de7FPLESTUvhBJYm7hojeezS1MKivMmxmQ0WUk8sr_Rsa_Voq_zC",
                "judgementNumber": "4630480557",
                "judgementDate": "1446-05-28",
                "city": "جدة",
                "hijriYear": 1446,
                "courtName": "المحكمة التجارية",
                "courtType": 1,
                "caseNumber": "4630480557",
                "isAppeal": false,
                "refereeNo": null,
                "mostView": false,
                "isFavorite": false
            },
            {
                "id": "ebKWM-7E855WjlEs99-2nBrP3pamLM2qYQyFMS66_3v9kKaWA9QwoqDlSA7U_Yur",
                "judgementNumber": "4630469421",
                "judgementDate": "1446-05-28",
                "city": "جدة",
                "hijriYear": 1446,
                "courtName": "المحكمة التجارية",
                "courtType": 1,
                "caseNumber": "4630469421",
                "isAppeal": false,
                "refereeNo": null,
                "mostView": false,
                "isFavorite": false
            },
            {
                "id": "QNcgh08P-xI3MpJaMN2c3f22LKS8cTyQXjabpWT31wyZwCUD2BOkRmtKx9-dgv6Q",
                "judgementNumber": "4630318419",
                "judgementDate": "1446-05-27",
                "city": "أبها",
                "hijriYear": 1446,
                "courtName": "المحكمة التجارية",
                "courtType": 1,
                "caseNumber": "4630318419",
                "isAppeal": false,
                "refereeNo": null,
                "mostView": false,
                "isFavorite": false
            }
        ],
        "pageNumber": 1,
        "pageSize": 12,
        "totalCount": 31072,
        "totalPages": 2590
    },
    "errors": []
} 

---

## Assistant (Build · gpt-5.3-codex · 9.5s)

_Thinking:_



Perfect — this is exactly what we needed.  
Yes, this confirms there **is an API** for cases/judgments.

- List endpoint (confirmed):  
  `POST https://laws-gateway.moj.gov.sa/apis/legislations/v1/Judgements/judgements-list`
- It supports pagination (`pageNumber`, `pageSize`, `totalPages`) and returns stable `id` for each judgment.
- Next required endpoint is the **details endpoint** (full text). Usually something like `.../Judgements/judgement-details` with `id`.

How to proceed now:
- Extract all pages from `judgements-list`.
- For each `id`, call details endpoint to get full judgment text.
- Parse citations from text (`المادة X من نظام Y`) -> map to normalized regulation articles in your DB (positives).
- Generate hard negatives from top-K retrieval.
- Build triplets and fine-tune.

So yes: your pipeline is now fully feasible.

If you share one Network request for the **details API** (URL + payload), I can give you the exact extractor script structure immediately.

---

## User

https://laws-gateway.moj.gov.sa/apis/legislations/v1/Judgements/get-details?id=tHmWFpfqu2BzzaDB9cFx36ET7Yuocyka9OFhNdoiqLGxJ82QICUjU2-Co2EdTa3o&lang=ar&IdentityNumber=
Request Method
GET
Status Code
200 OK
Remote Address
87.101.236.244:443
Referrer Policy
strict-origin-when-cross-origin {
    "statusCode": 200,
    "success": true,
    "message": "تم إتمام العملية بنجاح",
    "model": {
        "id": "1c7c8abb-3f6c-4eac-b9c0-e05b909fc703",
        "title": "القضية رقم 4470267991 لعام 1444 هـ",
        "decisionTitle": null,
        "hjriiYear": 1446,
        "year": null,
        "hasJudgment": true,
        "judgmentNumber": "4630220365",
        "judgmentHijriiDate": "1446-09-06",
        "judgmentDate": "2025-03-06T00:00:00",
        "judgmentFacts": null,
        "judgmentReasons": null,
        "judgmentRuling": null,
        "judgmentTextofRulling": "<p>الحمدلله والصلاة والسلام على رسول الله، أما بعد: <br>فلدى الدائرة الثامنة وبناء على القضية رقم ٤٤٧٠٢٦٧٩٩١ لعام ١٤٤٤ هـ <br><br>المدعي: <br>شركة (...) للتجارة والمقاولات<br>المدعى عليه:<br>شركة (...)<br><br>الوقائع:<br>تتلخص وقائع هذه الدعوى في أنه سبق وأن تقدم وكيل المدعية/ (...)، بصحيفة دعوى إلى المحكمة التجارية بالدمام جاء فيها: بتاريخ ١٢/٠٦/٢٠٢٠ تعاقدت المدعية شركة (...) مع المدعى عليها شركة (...) وذلك بشأن تنفيذ وتشييد أعمال انشائية بمشروع مملوك للمدعى عليها بمدينة (...) بالمنطقة (...) قيمة العقد مبلغ (٦٢,١٢٠,٠٥٠.٠٠) ، وقد قامت المدعية بتسليم المدعى عليها اثناء ابرام التعاقد عدد من الضمانات بنكية منها الضمان البنكي عن حسن الاعمال ذو الرقم (...) بمبلغ وقدرة ٦,٢١٢,٠٠٥ ستة ملايين ومائتان واثنى عشر ألف ريال وخمسة هلله وذلك بغرض ضمان حسن اعمال المشروع بالكامل(مرفق رقم ١ خطاب الضمان).وقامت موكلتي بتنفيذ عدد من الأعمال المتفق عليها خلال فترة تنفيذ الاعمال الا أن المدعى عليها قامت بوقف الاعمال وارسال خطاب بفسخ العقد ومنع المدعية من استكمال العمل (مرفق رقم ٢ خطاب الفسخ وانهاء العمل)، ثم قامت المدعى عليها بتسييل الضمان البنكي موضوع الدعوى دون وجه حق ورغم قيامها بفسخ التعاقد وعدم انتهاء المشروع وتنفيذ كامل الأعمال وهو ما سبب اضرار كبيرة للمدعية (مرفق رقم٣ ما يفيد حسم المبلغ من حساب المدعية البنكي)، ولهذا فان المدعية تقدمت بهذه الدعوى لمطالبة المدعى عليه بان ترد لها قيمة الضمان البنكي الذي قامت بتسييله دون وجه حق ودون تحقق الغرض الصادر من اجله الضمان البنكي، وعليه ومن جميع ما سبق نلتمس من فضيلتكم الحكم:أولا: إلزام المدعى عليها برد قيمة الضمان البنكي الصادر عن حسن الاعمال ذو الرقم (...) وبمبلغ وقدرة ٦,٢١٢,٠٠٥ ريال (ستة ملايين ومائتان وأثنى عشر ألف ريال وخمسة هللة) الصادر من البنك (...). ثانياً: إلزام المدعى عليها بأن تدفع للمدعية اتعاب محاماة مبلغ وقدره (٦٢٠,٠٠٠) ريال ستمائة وعشرون ألف ريال، هذه دعواي، وقدم سنداً لطلبه المستندات الآتية:١-اتفاقية الشراء الرئيسية للبضائع والخدمات، ممهورة بختم الطرفين، برقم(...).٢ خطاب ضمان الأعمال، على مطبوعات البنك (...)، ممهور بختم وتوقيع البنك، برقم (k٠٧٠٥٣٦)، وتاريخ،٢٠٢١/٠٣/١٨م. وقيدت القضية بالرقم المشار إليه أعلاه، وأحيلت إلى هذه الدائرة وباشرت نظرها حسب ما هو مثبت في محاضرها، وقد أودع وكيل المدعى عليها مذكرة الدفاع في النظام بتاريخ ٥/ ٦/ ١٤٤٤هـ ونصها كما يلي: الموضوع: مذكرة دفاع للدعوى رقم (٤٤٧٠٢٦٧٩٩١) والمقامة من شركة (...)، أولاً: نفيد الدائرة الموقرة أن المدعية قامت برفع دعوى أخرى أمام الدائرة التجارية الثانية عشرة بالمحكمة التجارية بالدمام في الموضوع ذاته برقم ٤٤٧٠٠٧١٢١٧ وتاريخ ١٨/٠٢/١٤٤٤ هـ. مرفق لفضيلتكم صحيفة دعوى المدعية في الدعوى الأخرى. (مرفق ١)، ثانياً: دفعنا الشكلي للدعوى المقامة من قبل المدعية: وفقاً للمادة الخامسة والسبعون من نظام المرافعات الشرعية والتي تضمنت على أنه يجب إبداء الدفوع الشكلية قبل أي طلب أو دفع في موضوع الدعوى، أتقدم إلى فضيلتكم بدفعنا شكلاً للدعوى المقامة من المدعية، وذلك على النحو الآتي: تضمن العقد لشرط وساطة: نصت المادة الثامنة والخمسون من اللائحة التنفيذية لنظام المحاكم التجارية على أنه يجب اللجوء إلى المصالحة والوساطة قبل قيد أي من الدعاوى المتعلقة بالعقود التي تتضمن الاتفاق - كتابة - على اللجوء إلى المصالحة والوساطة والتسوية الودية قبل اللجوء إلى القضاء. وعند النظر إلى الفقرة (٧-٤) من العقد المبرم بين موكلتي والمدعية نجد أن العقد تضمن شرط وساطة على أن تعقد في (...)، مقاطعة (...)، (...)، (...)، مما يترتب عليه وجوب اللجوء الى الوساطة في (...) قبل التوجه إلى القضاء. مرفق لفضيلتكم نسخة من العقد. (مرفق ٢)، الاختصاص القضائي الدولي: نص العقد المبرم بين موكلتي والمدعية في الفقرة (٧-٦) على أن يكون الاختصاص القضائي بشكل حصري للمحاكم في ولاية(...)، مقاطعة (...)، (...)، مما يترب عليه عدم اختصاص محاكم المملكة بالنظر في النزاعات الناشئة عن هذا العقد، النظام المختار: نص العقد المبرم بين موكلتي والمدعية في الفقرة (٧-٥) على ان يخضع العقد المبرم بين الطرفين لقوانين (...)، مما يترتب عليه عدم خضوع هذا العقد لأنظمة المملكة إعمالاً لإرادة المتعاقدين، نؤكد للدائرة الموقرة ان موكلتي تريد الاحتفاظ بحقها بالرد على موضوع الدعوى، ولكن تماشياً مع ما أتت به المادة الخامسة والسبعون من نظام المرافعات الشرعية تكتفي بدفعها شكلاً، استنادا على ما تقدم، ولئن العقد ملزم لطرفيه، لقوله تعالى ( يا أيها الذين آمنوا أوفوا بالعقود )، و لقول النبي صلى الله عليه وسلم ( المسلمون على شروطهم )، و استنادا على المادة الثامنة والخمسون من اللائحة التنفيذية لنظام المحاكم التجارية، أطلب من فضيلتكم عدم قبول دعوى المدعية وإلزامها بدفع مبلغ و قدره ٦٠٠,٠٠٠ ريال سعودي إلى موكلتي كأتعاب محاماة ا. هـ. ثم عقدت الدائرة جلسة مرئية في ٩/ ٦/ ١٤٤٤هـ وفيها حضر المشار إليهما بعالية وتشير الدائرة إلى أنها عقدت هذه الجلسة التحضيرية وذلك بعد تبلغ المدعى عليها وتبين للدائرة اختصاصها بنظر للدعوى وقبولها مبدئياً وبسؤال وكيلة المدعية عن دعوى موكلتها أحالت على صحيفة الدعوى -المشار لها بعالية-، وبعرض ذلك على وكيل المدعى عليها أفاد بأنه أرفق جوابه عبر الطلب على القضية وذلك بتاريخ ٠٥/٠٦/١٤٤٤ وبعرض ذلك على وكيلة المدعية أفادت أن لديها جواب تود إرفاقه فأرفقت عبر المحادثة ما نصه: (لرد على جواب المدعى عليها وما جاء فيه من دفوع شكلية. أولاً: ما يخص وجود دعوى أخرى منظورة أمام الدائرة التجارية الثانية عشر فهو صحيح لكن لا صلة بين الدعويين فهذه الدعوى تخص رد مبلغ خطاب الضمان المذكور بالدعوى أما الدعوى الأخرى فهي تخص رد وتسليم مستند، وعليه الدعويين مختلفين في الموضوع ثانياً: نود أن نوضح أن الدعوى المنظورة تخص المطالبة باسترداد قيمة خطاب ضمان سابق إصداره من المدعية للمدعى عليها واستقلال خطاب الضمان البنكي موضوع الدعوى عن عقد المقاولة المحرر بين الطرفين وانه يخرج عن العقد والاتفاق المحرر بينهما وما جاء فيه من بنود تخص حل النزاعات القضائية بل أن الضمان البنكي نص صراحة على (أي منازعة تخص هذا الخطاب يعتد بقوانين المملكة العربية السعودية) وعليه يكونا الاختصاص القضائي وفقاً لما ورد بالضمان يخضع لمحكمة الموضوع وهي المحكمة التجارية بالدمام. ثالثاً: الرد على ما جاء بشأن تضمن العقد لشرط الوساطة. جاء بمذكرة المدعى عليها ان بنود العقد نصت على اللجوء للوساطة قبل التقاضي إلا أن من المعروف ان الوساطة والمصالحة هو أجراء غير الزامي كون الوساطة أو المصالحة ليست جهة قضائية كالتحكيم إضافة إلى انه عند قيد الدعوى التجارية بنظام ناجز بيتم إحالتها لمنصة تراضي مباشرة من إدارة قيد الدعاوى لمحاولة الصلح ، كما ان الاتفاق الوارد في العقد عن الوساطة ذكر بان تتم الوساطة قبل صدور حكم نهائي وعليه يمكن عرض الصلح على الأطراف أثناء نظر الدعوى ولم يشترط في العقد ان تكون إجراءات الصلح قبل قيد الدعوى واستنادً للمواد (٥٩) و(٦٠) من اللائحة التنفيذية لنظام المحاكم التجارية يمكن إجراء المصالحة بعد قيد الدعوى. رابعاً: الرد على ما يخص الاختصاص القضائي الدولي. جاء بمذكرة رد المدعى عليها أن الاختصاص القضائي ينعقد لمحاكم ولاية (...) والرد على ذلك أن هذا الاتفاق يخالف المواد والقواعد الأمرة لنظام المرافعات الشرعية والتي نصت في المادة (٢٥) على (تختص محاكم المملكة بنظر الدعاوى التي ترفع على غير السعودي الذي له محل إقامة عام أو مختار في المملكة فيما عدا الدعاوى العينية المتعلقة بعقار خارج المملكة.) كما نصت الفقرة رقم (أ) من المادة (٢٦) من نظام المرافعات الشرعية على (تختص محاكم المملكة بنظر الدعاوى التي ترفع على غير السعودي الذي ليس له مكان إقامة عام أو مختار في المملكة في الأحوال الآتية:- إذا كانت الدعوى متعلقة بمال موجود في المملكة أو بالتزام تُعد المملكة مكان نشوئه أو تنفيذ)، إضافة الى ما نصت عليه الفقرة (٢) من المادة (١٧) من نظام المحاكم التجارية التي نصت على (في الدعاوى المتعلقة بالشركات، يكون الاختصاص المكاني للمحكمة التي يقع في نطاق اختصاصها المقر الرئيس للشركة، سواء كانت الدعوى على الشركة، أو من الشركة على أحد الشركاء، أو من شريك على آخر، أو على مديريها أو أعضاء مجلس إدارتها. ويجوز رفع الدعوى إلى المحكمة التي يقع في نطاق اختصاصها فرع الشركة في المنازعات الناشئة من التعاقد مع ذلك الفرع)، وعليه ولكون المدعى عليها شركة مقيدة بوزارة التجارة ولها مقر ثابت ومعلوم بالمملكة العربية السعودية وان العمل موضوع النزاع تم بالسعودية فيكون الاختصاص لمحاكم المملكة وذلك من القواعد الأمرة التي لا يجوز الاتفاق على مخالفتها وان موضوع الدعوى متعلق بمال موجود بالسعودية وهو خطاب الضمان البنكي موضوع الدعوى) ا. هـ. وبعرض ذلك على وكيل المدعى عليها تمسك بما قدم وعليه رفعت الجلسة للدراسة. وفي جلسة ٢٥/ ٦/ ١٤٤٤هـ حضر المشار لهما بعالية، وتشير الدائرة إلى أنها اطلعت على ملف القضية وسألت وكيل المدعى عليها عن موضوع الدعوى في الدائرة الأخرى في ذات المحكمة؟ أجاب هناك قضيتان: الأولى: (٤٤٧٠٠٧١٢١٧) وتطلب المدعية برد مبلغ خطاب الضمان، والثانية: (٤٤٧٠٥٢١٤١٢٥) وتطلب المدعية برد المعدات وكلها متفرعة عن نفس الموضوع، وبعرض ذلك على وكيل المدعية أجاب غير صحيح الدعوى تتعلق بخطاب ضمان آخر وتم الحكم بمنع التصرف بخطاب الضمان البنكي وهو مختلف عن الخطاب محل الدعوى. وعليه أفهمت الدائرة وكيل المدعى عليها بإرفاق صور من أحكام القضايا التي ذكرها، فاستعد بذلك، وأفهمت وكيل المدعية بإرفاق صورة خطاب الضمان البنكي فاستعد بذلك وعليه قررت الدائرة رفع الجلسة، وفي جلسة ١/ ٨/ ١٤٤٤هـ حضر المشار اليهم بعالية وتشير الدائرة إلى تقدم وكيل المدعى عليها بمذكرته بالأمس عبر النظام والمتضمنة عدد من الأحكام القضائية، ولم يتسنى الاطلاع عليها للتأخر في تقديمها، ثم أرسلت وكيلة المدعية عبر الاتصال المرئي ما نصه: (إشارة الى الدعوى المذكورة بأعلاه وبصفتي وكيلاً عن المدعي، أتقدم لفضيلكم بمذكره رد مقدمه من موكلي عما تم ذكره بالجلسة السابقة ٢٥/٠٦/١٤٤ه، وعليه أقول وبالله التوفيق. أولا: نؤكد انه ما تم ذكره من وكيل المدعي عليها انه هناك قضيتان: الأولى: (٤٤٧٠٠٧١٢١٧) وتطلب المدعية برد وتسليم خطاب الضمان والخاص بالدفعة المقدمة علما بان سبق أن صدر حكم لموكلتي من القضاء المستعجل بمنع المدعى عليها من التصرف في هذا الخطاب، والقضية الثانية: (٤٤٧٠٥٢١٤١٢٥) وتطلب المدعية برد المعدات الموجودة بالموقع لدى المدعى عليها، وهو ما يبين ان تلك القضايا وما بها من طلبات مختلفة عن القضية المنظورة أمام فضيلتكم. ثانيا: نؤكد على الضمان موضوع الدعوي هو الضمان البنكي عن حسن الأعمال ذو الرقم (...) بمبلغ وقدرة ٦,٢١٢,٠٠٥ ريال وذلك بغرض ضمان حسن أعمال المشروع بالكامل. وحيث انه المدعى عليها قامت بفسخ التعاقد مع المدعية وهو ما جعلها لا تقوم بتنفيذ كامل الأعمال ويجعل قياما لمدعى عليها بصرف وتسيل الضمان البنكي موضوع الدعوى غير صحيح لعدم استحقاقه ، ولهذا فان المدعية تقدمت بهذه الدعوى لمطالبة المدعى عليه بان ترد لها قيمة الضمان البنكي الذي قامت بتسييله دون وجه حق ودون تحقق الغرض الصادر من أجلة الضمان البنكي، وعليه ومن جميع ما سبق نلتمس من فضيلتكم الحكم:أولا: إلزام المدعى عليها برد قيمة الضمان البنكي الصادر عن حسن الأعمال ذو الرقم (...) وبمبلغ وقدرة ٦,٢١٢,٠٠٥ ريال (ستة ملايين ومائتان وأثنى عشر ألف ريال وخمسة هللة) الصادر من البنك (...). ثانياً: إلزام المدعى عليها بان تدفع للمدعية أتعاب محاماة مبلغ وقدره ٦٢٠٠٠٠ريال ستمائة وعشرون ألف ريال وتقبلوا خالص التحية والتقدير) ا. هـ. وعليه جرى إفهام وكيل المدعى عليها بالجواب الموضوعي عن الدعوى خلال عشرة أيام من تاريخه، ولوكيلة المدعية ذات المهلة للرد، وللاطلاع على ما سبق الإشارة إليه، رفعت الجلسة، وفي جلسة هذا اليوم حضر المشار لهما بعالية، وتشير الدائرة إلى تبادل الأطراف المذكرات عبر النظام، وبعد الاطلاع على ملف القضية، ولصلاحية الدعوى للفصل فيها رفعت الجلسة للمداولة والنطق بالحكم، فحكمت الدائرة بعدم اختصاص المحاكم التجارية بالمملكة العربية السعودية دولياً بنظر الدعوى المقامة من المدعية/ شركة (...) للتجارة والمقاولات سجل تجاري رقم: (...)، ضد المدعى عليها/ شركة (...) سجل تجاري رقم: (...)، ثم قدم وكيل المدعية اعتراضه على الحكم فأحيلت إلى الاستئناف، بما أن واقعات هذه القضية أحاط بها الحكم محل الاعتراض، لذلك فإن دائرة الاستئناف تحيل عليه درءاً للتكرار، بموجب ما نصت عليه المادة (٧٦/٢) من نظام المحاكم التجارية، أن تقدمت وكيل المدعية بهذه الدعوى أنه بتاريخ ١٢/٠٦/٢٠٢٠ تعاقدت المدعية شركة (...) مع المدعى عليها شركة (...) وذلك بشأن تنفيذ وتشييد أعمال إنشائية بمشروع مملوك للمدعى عليها بمدينة (...) بالمنطقة (...) قيمة العقد مبلغ (٦٢,١٢٠,٠٥٠.٠٠) ، وقد قامت المدعية بتسليم المدعى عليها أثناء إبرام التعاقد عدد من الضمانات بنكية منها الضمان البنكي عن حسن الأعمال ذو الرقم (...) بمبلغ وقدرة ٦,٢١٢,٠٠٥ ستة ملايين ومائتان واثنى عشر ألف ريال وخمسة هلله وذلك بغرض ضمان حسن أعمال المشروع بالكامل. وقامت موكلتي بتنفيذ عدد من الأعمال المتفق عليها خلال فترة تنفيذ الأعمال إلا أن المدعى عليها قامت بوقف الأعمال وأرسال خطاب بفسخ العقد ومنع المدعية من استكمال العمل، ثم قامت المدعى عليها بتسييل الضمان البنكي موضوع الدعوى دون وجه حق ورغم قيامها بفسخ التعاقد وعدم انتهاء المشروع وتنفيذ كامل الأعمال وهو ما سبب أضرار كبيرة للمدعية (مرفق رقم٣ ما يفيد حسم المبلغ من حساب المدعية البنكي)، ولهذا فان المدعية تقدمت بهذه الدعوى لمطالبة المدعى عليه بان ترد لها قيمة الضمان البنكي الذي قامت بتسييله دون وجه حق ودون تحقق الغرض الصادر من أجله الضمان البنكي، وعليه ومن جميع ما سبق نلتمس من فضيلتكم الحكم:أولا: إلزام المدعى عليها برد قيمة الضمان البنكي الصادر عن حسن الأعمال ذو الرقم (...) وبمبلغ وقدرة ٦,٢١٢,٠٠٥ ريال (ستة ملايين ومائتان وأثنى عشر ألف ريال وخمسة هللة) الصادر من البنك (...). ثانياً: إلزام المدعى عليها بأن تدفع للمدعية أتعاب محاماة مبلغ وقدره (٦٢٠,٠٠٠) ريال ستمائة وعشرون ألف ريال. أحيلت القضية إلى الدائرة الابتدائية، وأصدرت حكمها في النزاع المنتهي إلى عدم اختصاص محاكم المملكة ولائياً بنظر هذه الدعوى، ولم يحظ الحكم بقبولٍ من وكيل المدعية المحامي/ (...) فنعى عليه بمذكرة اعتراض؛ حاصلها تمسكها بنظر الدعوى، ذلك أنه سبق وأن صدر حكم هذه الدائرة في القضية رقم (٤٤۷۰۰۷۱۲۱۷) بذات الموضوع والطلبات، وتمسك بالحكم الصادر فيها، كذلك أنه أصدرت الدائرة حكمها بصرف النظر لعدم اختصاص محاكم المملكة العربية السعودية ولائياً على سند من اتفاق الطرفين في عقد المقاولة على اختصاص محاكم ولاية (...) في (...) بنظر أي خلاف على العقد ، وكما هو مبين في ملف الدعوى موضوع الاعتراض من أنها أقيمت من المدعية لغرض الزام المدعى عليها برد وتسليم خطاب الضمان البنكي ذو الرقم المرجعي (...)، وعليه فان ما يطبق ويعمل به فيما يخص الضمان البنكي هي الشروط والقواعد الواردة به ومنها انه قد نص فيه صراحة على( أي نزاع ينشأ عن هذا خطاب الضمان هذا يتم حسمه بموجب أنظمة وقوانين المملكة العربية السعودية) أي انه يخرج نهائياً عما ورد في عقد المقاولة المحرر بين الطرفين وما تضمنه من شرط اختصاص قضائي وهو ما يبين أن الدائرة مصدرة الحكم قد كيفت الواقعة تكييف غير صحيح، وطلب إعادة النظر في الحكم. باشرت دائرة الاستئناف نظر القضية، وانعقدت جلسة لذلك، وبعد الاطلاع على أوراق القضية من دائرة الاستئناف، رفعتها للمداولة، وأصدرت حكمها الماثل، فحكمت الدائرة بإلغاء الحكم الصادر بالصك رقم (٤٤٣٠٧٧٩٤٩٤) في هذه القضية، وإعادة الأوراق إلى الدائرة ناظرة القضية لاستكمال النظر، فأعيدت إلى الدائرة وحددت لها جلسة ٢٩/٠٥/١٤٤٥هـ، وفيها حضر الطرفان، وتشير الدائرة إلى عودة هذه القضية من دائرة الاستئناف بإلغاء الحكم الصادر من هذه الدائرة، وبسؤال وكيلة المدعية عما لديها من إضافة، أجابت بأن هناك حكم مشابه لهذه الدعوى وصدر بإلزام المدعى عليها، وأن الفسخ في هذه الدعوى صدر من المدعى عليه، وعليه أفهمتها الدائرة بتقديم الحكم المشار إليه عبر النظام خلال عشرة أيام من هذه الجلسة، وبسؤال وكيل المدعى عليها عما لديه من إضافة، أجاب قائلًا: نطلب مهلة لتقديم الجواب المفصل والملاقي مع المستندات المترجمة، والحكم الذي أشارت له وكيلة المدعية لم يكتسب القطعية وتم الاعتراض عليه، وعليه أفهم بتقديم إجابته خلال عشرة أيام تبدأ من تاريخ: ٠٩/ ٠٦/ ١٤٤٥ هـ، ولوكيل المدعية تقديم مذكرتها بعد ذلك قبل موعد الجلسة القادمة بأسبوع على الأقل على أن يكون تقديم المذكرات بالنص في الخانة المخصصة لذلك، ويتم تقديم المستندات بصيغة PDF، وفي تاريخ ١٩/٠٦/١٤٤٥هـ، أودع وكيل المدعى عليها مذكرة أفاد فيها أولا: قامت موكلتنا بفسخ العقد مع المدعية بتاريخ ٢٩/٠٦/٢٠٢٢م، وذلك لإهمال وتقصير المدعية وعدم التزامها بما نص عليه العقد من مهام &lrm;والتزامات، ونؤكد على صحة فسخ العقد من قبل المدعى عليها استنادا إلى الفقرة الثانية من المادة السابعة من العقد ونصها التقصير والإنهاء في حالة قيام البائع بما يلي: (أ) مخالفة هذه الاتفاقية أو التقصير بموجب أي شرط في هذه الاتفاقية وعدم معالجة هذا المخالفة أو التقصير في غضون عشرة &lrm;( ١٠) أيام بعد إشعار من شركة(...) (ب) الإفلاس أو إعادة التنظيم أو الحراسة القضائية أو الإعسار أو إجراء التنازل الصالح الدائنين: أو (ج) دليل على عدم الاستقرار المالي أو التنظيمي، يحق لشركة (...)، بالإضافة إلى أي حقوق أو تعويضات قد تكون مستحقة لها بموجب القانون أو &lrm;العدالة أو بموجب هذه الاتفاقية لإلغاء هذه الاتفاقية على الفور سبب وذلك بموجب إشعار كتابي للبائع، عند الانتهاء من قبل (...) نتيجة تقصير البائع بموجب هذه الاتفاقية، سيكون البائع مسؤولا وسيعوض على الفور شركة (...) عن جميع التكاليف من أي نوع كانت بما يتجاوز &lrm;بن &lrm;السعر المعمول به بموجب هذه الاتفاقية والتي تكون قد تكبدتها (...) لإتمام الأداء وفقا لهذه الاتفاقية أو أي أوامر شراء صادرة بموجها ، وقد قامت المدعية بالتقصير في أعمالها، وذلك في عدم تنفيذ الأعمال المطلوبة منها بموجب العقد على أكمل وجه، وقد &lrm;أخفقت في الكثير من التزاماتها مع قيام المدعى عليها بإشعارها حول هذه الإخفاقات عدة مرات، كما نود أن نوضح لأصحاب الفضيلة ما يلي: ١- &lrm;مع جميع الإخفاقات التي قامت بها المدعية أعطت المدعى عليها المدعية مهلة ٦ أشهر بعد نهاية العقد لتصحيح وضعها وإنجاز الأعمال، إلا أن &lrm;المدعية للأسف لم تنجز من الأعمال سوى ما نسبته (%۳۱) من العقد، وقد فشلت في تسليم المشروع بالتاريخ المحدد في ٢٣/١٢/٢٠٢١م، ٢- &lrm;إن المدعية توقفت عن العمل، وقامت بالتلاعب في تقارير الأعمال، ولم توفر الأيادي العاملة المطلوبة، كما أن ممثلين المدعية لم يلتزموا &lrm;بالدوام والحضور في موقع المشروع من خلال غيابتهم المتكررة دون مبرر، ٣- &lrm;إن المدعية أقرت بأخطائها، وأقرت بأنها تأخرت عن تنفيذ الأعمال، ولم تستطيع توفير العمالة الكافية للمشروع لإنجاز الأعمال، وذلك الأسباب تعود إليها، منها سوء تقديرها لعدد العمال، ومشاكل مالية، تسبب هذا كله في عدم إنجاز المشروع، ٤- &lrm;عطفا على ذلك كله، لقد قامت موكلتنا بإشعار المدعية عن جميع الإخفاقات والأخطاء والتجاوزات، ولكن لم تقم المدعية بتصحيح هذه الإخفاقات والأخطاء، ولم تجد المدعى عليها الجدية منة قبل المدعية في ذلك، ثانياً: الضمان محل الدعوى هو ضمان حسن الأعمال، فهو ضمان مقدم من المدعية للمدعى عليها كضمانة منها على حسن تنفيذ الأعمال والالتزام بجميع &lrm;بنود العقد، وعليه فإنه في حال عدم التزام المدعية بتنفيذ الأعمال على أكمل وجه، وعدم التزامها بالعقد، فذلك يعطي الحق للمدعى عليها لتسيل هذا الضمان بقدر الضرر والخسائر التي تعرضت له المدعى عليها من عدم التزام المدعية بالعقد وتنفيذه مع إشعارها بتصحيح الوضع عدة مرات، وهذا ما قد حصل للمدعى عليها بالفعل فقد تكبدت خسائر وأضرار تفوق قيمة ضمان حسن الأعمال بكثير، ويؤكد ذلك ما نصت عليه الفقرة الثانية من المادة الرابعة &lrm;من نظام الفيديك يعطي الحق للمدعى عليها بتسهيل هذا الضمان الاسترداد جزء من الأضرار التي وقعت عليها، ثالثا: غير صحيح ما ذكرته المدعية من أن العقد غير محدد المدة، والصحيح أن مدة العقد (۱۲) شهر تبدأ من تاريخ توقيع العقد في ٢٣/١٢/٢٠٢٠م، &lrm;وتنتهي بتاريخ ٢٣/١٢/٢٠٢١م، وذلك وفق ما نص عليه المرفق أ من العقد المرفق ١ من هذه المذكرة، كما أقرت المدعية بتاريخ انتهاء العقد في خطابها. في المرفق رقم ٢ أعلاه، &lrm;رابعا: الأضرار والخسائر التي تكبدتها المدعى عليها بسبب المدعية، والتي تحتفظ المدعى عليها بحقها في المطالبة بها بدعوى مستقلة، تتمثل على سبيل المثال لا &lrm;الحصر فيما يلي: ١/ &lrm;التأخر في تنفيذ المشروع، حيث إن المشروع بموجب العقد ينتهي بتاريخ٢٣/١٢/٢٠٢١م، وللأسف حتى تاريخ فسخ العقد في ٣٠/٠٦/٢٠٢١م، لم تقم المدعية بإنجاز أعمال المشروع، بل لم تقم بأعمال سوى ما نسبته %۳۱، وذلك وفق ما قدره الخبير المندوب من &lrm;المحكمة لإثبات الحالة في الدعوى التي تقدمت به المدعية ١١٥ ٤٣٩٥٥٤ وتاريخ ١٤٤٣/١٢/٢٢هـ، كما أنه بناء على الفقرة السابعة من المادة الثامنة من نظام الفيديك أحد ملاحق العقد، فإن المدعى عليها &lrm;تستحق غرامة تأخير قدرها (٦,٢١٢٠٠٠٥) ريال، حيث أنها تأخرت أكثر من (۱۸۰) يوم والغرامة قدرها (۰.۱۱۱%) عن كل يوم، على أن لا &lrm;تتجاوز الغرامة ١٠% من قيمة العقد عليه فإن المدعى عليها تستحق تعويض قدره (۱,۲۱۲۰۰۰۵) ريال، ما يمثل ١٠٪ من قيمة العقد، ٢/ &lrm;أخطاء في التنفيذ قامت به المدعية، اضطرت المدعى عليها لتعديلها تتمثل في مبالغ تتجاوز مبلغ وقدره (۸٤۲,۸۷٦,۹۵) ريال، ٣/ قيمة فرق التعاقد مع المقاول الجديد، حيث اضطرت المدعى عليها للتعاقد مع مقاول جديد لإكمال الأعمال وتنفيذ بقية المشروع، فقد اضطرت &lrm;المدعى عليها تدفع مبلغ وقدره (١٩,٩٦١,٨٣٤,٦٧ ريال إضافي، وهو يمثل فرق قيمة التعاقد مع المقاول الجديد، حيث أن العقد الأساسي مع &lrm;المدعية كان بمبلغ وقدره (٦٢,١٢٠,٠٥٠) ريال، والأعمال المنفذة من المدعية قدرها (١٩,٢١٧,٨٥٣,٤٨) ريال بناء على تقرير الخبير المعين &lrm;من المحكمة، والمتبقي من الأعمال قدرها (۲,۱۹٦,٥٢ ٤۲,۹٠ ريال، واضطرت المدعى عليها للتعاقد مع المقاول الجديد بمبلغ وقدره &lrm;(٤٩,٨٦٤,٠٣١,١٩) ريال، فعليه فإن المدعى عليها اضطرت الدفع مبلغ وقدره (٦,٩٦١,٨٣٤,٦٧) ريال إضافي عن قيمة العقد مع المدعية بسبب &lrm;فسخ العقد مع المدعية وإكمال الأعمال،٤/ قيمة الأعمال التي لم يتم تضمينها في مبلغ المقاول الجديد أعلام قدرها ( ١١,٦٣٥,٩٦٨,٨١) ريال، وهذه المبالغ اضطرت المدعى عليها لخفضها من &lrm;العقد الجديد وذلك لتجاوز الميزانية الأصلية وسرعة إنجاز الأعمال، ٥/ تكاليف أخرى تكبدتها المدعى عليها نتيجة لفسخ العقد مع المدعية ومن هذه التكاليف: خدمات إدارة المشروع وخدمات الإشراف وأمن الموقع والمياه والديزل واستئجار المولدات والتنظيف وتقدر هذه التكاليف تقريباً مبلغ وقدره (۱۰,۱۳۸,۰۸٦) ريال، ٦/ علما بأن جميع التكاليف المذكورة أعلاه لا تشمل ضريبة القيمة المضافة، وختم مذكرته بطلب ١/ رفض دعوى المدعية لعدم استحقاقها وفق ما تم بيانه، ٢/ الزام المدعية بتعويض المدعى عليها عن أتعاب المحاماة قدرها (٣٥٣,٢٦٠) ريال، ٣/ احتفاظ المدعى عليها بحقها في المطالبة بالأضرار والخسائر في دعوى مستقلة، وفي تاريخ ٠٢/٠٧/١٤٤٥هـ، أودع وكيل المدعية مذكرة أفاد فيها أولاً: أقرت المدعى عليها بدعوى المدعية من حيث التعاقد وتسليمها ضمان بنكي لحسن الأعمال ذو الرقم (...) بمبلغ وقدرة ٦,٢١٢,٠٠٥ ستة ملايين ومائتان واثنى عشر ألف ريال وخمس هلله وقيامها بفسخ العقد وتسييل الضمان البنكي المسلم لها، ثانياً: ما جاء برد المدعى عليها من تفاصيل وادعاءات تخص فسخ العقد فهي غير صحيحة نهائياً بل إنها تخرج عن نطاق الدعوى والتي تنحصر في طلب المدعية برد قيمة الضمان البنكي الذى سلم للمدعى عليه كضمان لحسن أعمال المشروع المتفق عليه والخاص بنفيذ وتشييد أعمال إنشائية بمشروع مملوك للمدعى عليها بمدينة (...) بالمنطقة (...) وكانت قيمة العقد مبلغ (٦٢,١٢٠,٠٥٠.٠٠) وقد قامت المدعية بتسليم المدعى عليها أثناء إبرام التعاقد عدد من الضمانات البنكية منها الضمان البنكي عن حسن الأعمال ذو الرقم (...) بمبلغ وقدرة ٦,٢١٢,٠٠٥ ستة ملايين ومائتان واثنى عشر ألف ريال وخمس هلله وذلك بغرض ضمان حسن أعمال المشروع بالكامل إلا أن المدعى عليها لم تستمر في تنفيذ العقد ولم تُمكِّن المدعية من تنفيذ المشروع وقامت بفسخ العقد وإخلاء المدعية من الموقع وهو ما يجعل الضمان البنكي الخاص بحسن الأعمال غير مستحق للمدعى عليها كون الأصل في الضمان البنكي لحسن الأعمال يكون لصالح مالك المشروع وذلك لمراقبة والتأكد من صحة وسلامة أعمال العقد ولا يتم تسييله إلا إذا امتنع (المقاول) المدعية عن ضمان وصيانة الأعمال وحيث أن المدعى عليها هي من قامت بفسخ العقد ولم يتم تنفيذ العقد فلا يكون لها الحق في الاحتفاظ بالضمان البنكي الخاص بحسن الأعمال لعدم موجب ذلك إلا أن المدعى عليها قامت بما هو اكثر من الاحتفاظ بالضمان البنكي حيث قامت بتسييل وصرف الضمان البنكي دون وجه حق وإلحاق ضرر كبير بالمدعية ولهذا فالمدعية تقدمت بهذه الدعوى لرد قيمة ضمان حسن الأعمال الذى تسلمته المدعى عليها ثالثاً: المدعى عليها تحاول في الجواب المقدم منها الخروج عن موضوع الدعوى وتحويل نظر الدائرة الموقرة عن طلبات الدعوى والخاصة برد قيمة ضمان حسن الأعمال إلى تفاصيل وبنود العقد والذى يخرج نهائيا عن موضوع الدعوى وذلك وفقاً لما سبق أن أكدت عليه محكمة الاستئناف عندما قامت بنقض الحكم السابق صدوره في هذه الدعوى والخاص بالاختصاص القضائي وصلة الضمان بالعقد وأكدت على عدم ارتباط موضوع الدعوى وخطاب الضمان بتفاصيل العقد، وحيث أن ما ورد بمذكرة المدعية من خوض في موضوع العقد وتفاصيل العمل هي ذات الوقائع التي ساقتها فيما يتعلق بدعوى رد خطاب ضمان الدفعة المقدمة وتناولها حكمي الاستئناف وأول درجة بالتفنيد والتسبيب ولهذا فإننا لن ننجرف لمحاولات المدعى عليها في الخوض في تفاصيل التعاقد والمشروع وأسباب الفسخ ونترك ذلك للدعوى الموضوعية التي ستنظر لبيان وتحديد حقوق كل طرف تجاه الأخر وفقاً للعقد وما تم فيه من أعمال ومخالفات كل طرف ونكتفى في هذه الدعوى بما ورد فيها من طلبات تتمثل في رد قيمة ضمان حسن الأعمال التي قامت المدعى عليها بتسييله دون وجه حق، رابعاً: صدور حكم نهائي من دائرة الاستئناف الثانية بالمحكمة التجارية بالدمام يثبت حق المدعية في المطالبة بالضمانات البنكية التي سلمت للمدعى عليها وقت توقيع العقد حيث سبق أن أقامت المدعية دعوى برد خطاب ضمان الدفعة المقدمة والتي سبق أن تسلمتها المدعية من المدعى عليها أثناء توقيع العقد والمقدر بنفس مبلغ خطاب ضمان حسن الأعمال بما نسبته ١٠في المائة من قيمة العقد وصدر فيها بتاريخ ١٤ـ٠٦ـ١٤٤٥ حكم نهائي بتأييد الحكم الصادر من الدائرة التجارية الثالثة بالمحكمة التجارية بالدمام فيما قضى به من أحقية المدعية في استرداد خطاب ضمان الدفعة المقدمة محمولا على ما يلي من أسباب (وتتفق دائرة الاستئناف مع الدائرة مصدرة الحكم في تكييف خطاب الضمان وما قدمه المستأنف سبق الإجابة عليه من الدائرة مصدرة الحكم في أسبابها من خلال توافق المدعى عليها مع المدعية أمام الدائرة الابتدائية على كون الأعمال المنفذة تفوق قيمة الدفعة المقدمة) هذا وقد كان حكم محكمة الدرجة الأولى قد اكد في أسبابه على (الأمر الذي تجد فيه الدائرة سندا كافيا لعدم تسويغ احتفاظ المدعى عليها بالخطاب.، وعليه فلا مسوغ لتسخير هذه الكفالة في غير محلها الذي قيدت لأجله بتسييلها لغرض صرف مستحقات مقاولي الاستكمال أو أي أغراض أخرى) وإن كان ذلك حال خطاب ضمان الدفعة المقدمة الذي سبق أن قبضته المدعية، فما بالنا بضمان حسن الأعمال ( موضوع هذه الدعوى) والذي حررته المدعية للمدعى عليها ضمانا لحسن تنفيذ كامل أعمال المشروع بعد تسليمه والانتهاء منه والذى كانت قيمته تقارب (واحد وستين مليون ريال)،إلا أن المدعى عليها هي من منعت المدعية من تنفيذ المشروع وقامت بفسخ العقد من جانب واحد وعليه فلا يكون هناك سبب أو موجب لاحتفاظ المدعى عليها بالضمان من الأساس وحيث أن المدعى علها تجاوزت مسألة الاحتفاظ بالضمان وقامت بتسييل وصرف الضمان البنكي لحسن الأعمال في غير الغرض والغاية الصادر لها وهو ما يوجب عليها رد قيمة هذا الضمان استناداً لما سبق أن صدر في دعوى رد وتسليم ضمان الدفعة المقدمة ( مرفق صك الحكم الابتدائي وصك حكم الاستئناف ) وذلك لوحدة اطراف النزاع وموضوع الدعوى والخاص بالضمانات البنكية المسلمة من المدعية للمدعى عليها، وفي جلسة ١٢/٠٧/١٤٤٥هـ، وفي هذه الجلسة حضر الطرفان، وسالت الدائرة الأطراف عما يودان إضافته فأفادت وكيلة المدعية بانها تكتفي بما قدم وأضاف وكيل المدعى عليها عبر المحادثة ما نصه (نود أن نوضح للدائرة الموقرة ما يلي: أولا: أن الضمان محل الدعوى مرتبط بالعقد والالتزام به التزاما كليا كونه يتعلق بحسن تنفيذ أعمال العقد وبنوده وهو ما لم تقم به المدعية بل على العكس تكبدت موكلتي خسائر تفوق مبلغ الضمان بكثير وذلك بسبب المدعية. ثانيا: أن سكوت المدعية منذ فسخ العقد حتى تاريخه، وعدم تقديمها أي دعوى بسبب فسخ العقد، يؤكد صحة فسخ العقد وعلم المدعية بأنها أخلت ببنود العقد وأن الفسح في محله. ثالثا: أن الضمان محل الدعوى هو مختلف بالكلية عن الضمان في الدعوى الأخرى، فالضمان في هذه الدعوى هو ضمان عن حسن الأعمال وهو ما أخلت المدعية به من تنفيذ الأعمال بشكل صحيح كما سبق بيانه في المذكرة المقدمة، أما ما الضمان الأمر فهو ضمان للدفعة المقدمة وهو مختلف في شروطه وأحكامه وموجبه ولا يمكن الربط بينهما. أخير: نطلب منكم صاحب الفضيلة السماح لنا بإرسال تقرير الخبير المندوب من المحكمة والذي قدم تقريره واكد على نسبة الأعمال المنفذة وقيمتها والتي لا تتجاوز نسبة ٣١ ٪؜.)، وطلب وكيل المدعى عليها مهلة لتقديم تقرير الخبير في القضية الأخرى فأفهمته الدائرة بتقديم ما لديه عبر الطلبات ذلك خلال أسبوع من تاريخ اليوم وان لوكيلة المدعية مدة مماثلة لتقديم ما لديها، وفي تاريخ ١٩/٠٧/١٤٤٥هـ، أودع وكيل المدعية مذكرة أفاد فيها أولاً: نؤكد ونتمسك بكل ما سبق تقديمه من دفوع وطلبات بمذكراتنا السابقة، ثانياً: ما جاء برد المدعى عليها من تفاصيل وادعاءات تخص فسخ العقد تخرج عن نطاق الدعوى الماثلة والتي ينحصر موضوعها في طلب المدعية رد قيمة الضمان البنكي الذى سُلم للمدعى عليها كضمان لحسن أعمال المشروع المتفق عليه والخاص بنفيذ وتشييد أعمال إنشائية بمشروع مملوك للمدعى عليها بمدينة (...) بالمنطقة (...) وكانت قيمة العقد مبلغ (٦٢,١٢٠,٠٥٠.٠٠) ، وقد قامت المدعية بتسليم المدعى عليها عند توقيع العقد عدد من الضمانات البنكية منها الضمان البنكي الخاص بحسن الأعمال ذو الرقم (...) بمبلغ وقدرة ٦,٢١٢,٠٠٥ ستة ملايين ومائتان واثنى عشر ألف ريال وخمس هالات وذلك بغرض ضمان حسن أعمال المشروع بالكامل. إلا أن المدعى عليها لم تستمر في تنفيذ العقد ولم تُمكِّن المدعية من تنفيذ المشروع وقامت بفسخ العقد وإخلاء المدعية من الموقع، ثالثا: سبق أن تقدمت المدعى عليها بذات المرفقات في بداية الدعوى وفي الدعوى السابقة برد خطاب الضمان البنكي الخاص بالدفعة المقدمة والتفتت عنها المحكمة لعدم اتصالها بموضوع الدعوى وقد صدر حكم دائرة الاستئناف الثانية بالمحكمة التجارية بالدمام مؤيدا لما انتهى له حكم أول درجة، ولاتحاد موضوع الدعويين، الخاصة برد خطاب ضمان الدفعة المقدمة والخاصة برد قيمة خطاب ضمان حسن الأعمال، وخروج كليهما عن نطاق الدعوى الموضوعية بتقييم حجم المنفذ من الأعمال في ضوء تنفيذ الأطراف لالتزاماتهما، فإن مجال تلك المرفقات المقدمة من المدعى عليها وخاصة تقرير الخبير الهندسي المبين به أعمال المشروع أو قيمة الأعمال وما تم تنفيذه وما لم بنفذ أو ما يخص مناقشة وبحث مدى التزام كل طرف ببنود العقد والضرر الواقع على الأطراف هو نزاع موضوعي أخر يحتاج فيه لإقامة دعوى أمام الجهة المختصة لإثبات التقصير والمطالبة بالتعويض أو المطالبة بقيمة الأعمال ، وهو ما شرعت موكلتي في اتخاذ الإجراءات الخاصة بها للمطالبة بمستحقاتها العالقة بذمة المدعى عليها وفقاً لبنود العقد، رابعا: تحاول المدعى عليها الخروج عن موضوع الدعوى وتحويل نظر الدائرة الموقرة عن طلبات الدعوى والخاصة برد قيمة ضمان حسن الأعمال إلى تفاصيل وبنود العقد وما تم في المشروع والذي يخرج كلياً عن موضوع الدعوى حيث أن موضوع الدعوي هو إلزام المدعى عليها برد قيمة خطاب الضمان البنكي ذو الرقم المرجعي (...) وأن هذا الضمان له شروط وقواعد منفصلة عما جاء بشروط وبنود عقد المقاولة وعليه فإنه يخرج عما ورد في عقد المقاولة المحرر بين الطرفين وما تضمنه من شرط اختصاص تخرج من ولاية الدائرة ناظرة الدعوى والتي تنحصر ولايتها في الضمان البنكي موضوع الدعوى، خامسا: نؤكد على صدور حكم نهائي من دائرة الاستئناف الثانية بالمحكمة التجارية بالدمام يثبت حق المدعية في استرداد الضمانات البنكية التي سلمت للمدعى عليها وقت توقيع العقد حيث سبق أن أقامت المدعية دعوى برد خطاب ضمان الدفعة المقدمة والتي سبق أن تسلمتها المدعية من المدعى عليها أثناء توقيع العقد والمقدر بنفس مبلغ خطاب ضمان حسن الأعمال بما نسبته ١٠ في المائة من قيمة العقد وصدر فيها بتاريخ ١٤/٠٦/١٤٤٥ حكم نهائي بتأييد الحكم الصادر من الدائرة التجارية الثالثة بالمحكمة التجارية بالدمام فيما قضى به من أحقية المدعية في استرداد خطاب ضمان الدفعة المقدمة، سادسا: المدعى عليها هي من منعت المدعية من تنفيذ المشروع وقامت بفسخ العقد من جانب واحد وعليه فلا يكون هناك سبب أو موجب لاحتفاظ المدعى عليها بضمان حسن الأعمال من الأساس وحيث أن المدعى عليها تجاوزت مسألة الاحتفاظ بالضمان وقامت بتسييل وصرف الضمان البنكي لحسن الأعمال في غير الغرض والغاية الصادر لها وقد سبب ذلك ضرر كبير للمدعية وهو ما يوجب على المدعى عليها رد قيمة هذا الضمان، وبناء عليه ولما سبق ذكره من أسباب نلتمس من فضيلتكم الحكم للمدعية، وختم مذكرته بطلب أولا: إلزام المدعى عليها بأن ترد وتدفع للمدعية قيمة ضمان البنكي لحسن الأعمال ذو الرقم (...) مبلغ وقدرة ٦,٢١٢,٠٠٥ ستة ملايين ومائتان وأثنى عشر ألف ريال وخمسة هللة الصادر من البنك (...)، ثانياً: إلزام المدعى عليها بأن تدفع للمدعية أتعاب محاماة مبلغ وقدره ٦٢٠٠٠٠ريال ستمائة وعشرون ألف ريال، وفي تاريخ ١٠/٠٨/١٤٤٥هـ، أودع وكيل المدعى عليها مذكرة أفاد فيها كما نؤكد لكم ارتباط الضمانات البنكية بالعقود المصدرة لأجلها، فلو لم يكن هناك عقد بين الطرفين، فلن يتم إصدار ضمان بنكي من الأساس، وبالنظر إلى الضمان محل الدعوى فإنه ضمان حسن أعمال أي أن استحقاق المدعى عليها لهذا الضمان هو مدى التزام المدعية بالعقد، ويؤكد هذا الأمر إقرار المدعية في مذكرتها المدونة في تاريخ ٢٨/٠٦/١٤٤٥هـ، الموافق ١٠/٠١/٢٠٢٤م، في الفقرة (ثانيا) من المذكرة حيث ذكرت كون الأصل في الضمان البنكي الحسن الأعمال يكون لصالح مالك المشروع وذلك لمراقبة والتأكد من صحة وسلامة أعمال العقد ولا يتم تسبيله إلا إذا امتنع (المقاول) المدعية عن ضمان وصيانة الأعمال فالمدعية أقرت باستحقاق المدعى عليها لتسبيل الضمان محل الدعوى وذلك لعدم التزامها بصحة وسلامة أعمال العقد وفق ما سبق بيانه بشكل مفصل مع الأسانيد في المذكرات السابقة، والذي تثبت فشل المدعية في تنفيذ أعمالها مرارا وتكرارا وعجزها التام عن إكمال المشروع &lrm;وأخيراً توضح لكم أصحاب الفضيلة أن الضمان البنكي لحسن الأعمال صادر لصالح المدعى عليها وتسبيله حق المدعى عليها لفشل المدعية في تنفيذ أعمال العقد، وفق ما ثبت تقديمه من فشل المدعية في مختلف الالتزامات وعجزها لأسباب تعود لها، مما يجعل دعواها حرية بالرفض، وختم مذكرته بطلب رفض دعوى المدعية لعدم استحقاقها، وفي جلسة ١١/٠٨/١٤٤٥هـ، افتتحت هذه الجلسة، وفيها حضر الطرفان، وتشير الدائرة إلى تقدم وكيل المدعى عليها بمذكرة بتاريخ الأمس، وبعرضها على وكيل المدعية أجاب: نكتفي بما تقدم، واكتفى وكيل المدعى عليها بما تقدم، وعليه قررت الدائرة حجز هذه القضية للدراسة، وفي جلسة ١٥/١٠/١٤٤٥هـ، افتتحت هذه الجلسة، وفيها حضر الطرفان، وبعد دراسة ملف القضية والاطلاع على ما قدمه الطرفان، رأت الدائرة حاجة القضية لندب جهة خبرة هندسية وذلك لدراسة مدى صحة تسييل المدعى عليها لخطاب الضمان البنكي محل هذه الدعوى وفقًا لما ورد فيه وبيان النتيجة النهائية في ذلك، وبعرض ذلك على الطرفين، أجابت وكيلة المدعية بإحالة ذلك لتقدير الدائرة، وبعرض ذلك على وكيل المدعى عليها أجاب لا مانع لدينا من ندب الخبير، وعليه رفعت الجلسة لإصدار قرار ندب الخبير، وفي تاريخ ٠٣/١٢/١٤٤٥هـ، أودع الخبير تقريره النهائي المشتمل على ملاحظات الأطراف وردة عليها، خلاصة التقرير النهائي: بعد إعداد الدراسة السابق تفصيلها والتي نتجت عن مراجعة المراسلات و المستندات بين الطرفيين و بمراجعة خطاب الضمان ذو الرقم المرجعي (...) و تاريخه ١٨/٠٣/٢٠٢١م، فشل المدعي / شركة (...) للتجارة و المقاولات في أداء التزاماتها طبقا للتعاقد بين الطرفيين، و بما أن خطاب الضمان ، ضمان من البنك المصدر له للعميل الموجه إليه على النطاق المحدد في مضامينه، و حيث تبين أن خطاب الضمان ذو الرقم المرجعي (...) و تاريخه ١٨/٠٣/٢٠٢١م، الصادر من البنك (...)، الغاية منه ضمان حسن أداء المدعي و التزامه بأداء التزاماته المنوطة إليه في التعاقد بين الطرفيين، و بما أن المدعي تبين أن نسبة إنجازه هي ٣١ % من قيمة التعاقد و خطاب الضمان يمثل ١٠ % من مبلغ العقد ، نجد أن القيمة الفعلية لعقد المدعي هي (١,٩٢٥,٧٢١٥) فقط، وعليه يكون استحقاق المدعي عليها بصرف مبلغ و قدره فقط (١,٩٢٥,٧٢١) فقط مليون و تسعمائة و خمس و عشرون الف و سبعمائة و واحد و عشرون ريال سعودي، من خطاب الضمان ذو الرقم المرجعي (...)، و الذي قيمته هي (٦,٢١٢,٠٠٥) فقط ستة ملايين و مئتان و اثني عشر ألفا و خمس ريالات سعودي، أولا: ملاحظات المدعي عليها على تقرير الخبير ورد الخبير عليها / شركة (...): ورد من المدعي عليها بتاريخ ٠٢/١٢/١٤٤٥هـ، الموافق ٠٨/٠٦/٢٠٢٤م، خطاب مكون من صفحه واحده يعرض جميع ملاحظاته على التقرير المبدئي و كانت كما يلي:١/ تم التأكيد في التقرير على ثبوت وجود تأخير في المشروع على المدعية ٤٠٠ يوم و بموجب العقد فإن المدعى عليها تستحق غرامة تأخير مقدرة بنسبة (٠.١١١%)؛ رد الخبير: نوضح أنه من مهامنا فقط النظر في مدى استحقاق المدعي عليها في تسييل خطاب الضمان ذو المرجع (...) و على ذلك لا علاقة لنا فيما هو خالف ذلك، ٢/ تم التأكيد في التقرير على أن المدعية لم تنفذ عملها على أكمل وجه والمدعى عليها محقة في فسخ العقد ، و لم ينظر الخبير لتكلفة التعاقد مع المقاول الجديد، رد الخبير: نوضح أنه لم يتم الحكم خلال تقريرنا على مدى جودة أعمال المدعية ولا علم لنا بها و أنه من مهامنا فقط النظر في مدى استحقاق المدعي عليها في تسييل خطاب الضمان ذو المرجع (...) و على ذلك لا علاقة لنا فيما هو خالف ذلك، ٣/ قيمة الأعمال التي لم يتم تضمينها في مبلغ المقاول الجديد قدرها١١٦٣٥٩٦٨.٨١ وهذه المبالغ اضطرت المدعى عليها لخفضها من العقد القديم؛ رد الخبير: نوضح أنه من مهامنا فقط النظر في مدى استحقاق المدعي عليها في تسييل خطاب الضمان ذو المرجع (...) و على ذلك لا علاقة لنا فيما هو خالف ذلك، ٤/ أخطاء في التنفيذ قامت به المدعية، اضطرت المدعى عليها لتعديلها تمثلت في مبالغ تتجاوز ٨٤٢٨٧٦.٩٥، رد الخبير: نوضح أنه لم يكن من مهامنا الحكم على مدى جودة أعمال المدعية ولا علم لنا بها و أنه من مهامنا فقط النظر في مدى استحقاق المدعي عليها في تسييل خطاب الضمان ذو المرجع (...) و على ذلك لا علاقة لنا فيما هو خلافه، ٥/ تكاليف أخرى تكبدتها المدعى عليها نتيجة لفسخ العقد مع المدعية و من هذه التكاليف خدمات إدارة المشروع و خدمات الإشراف و أمن الموقع و المياه و الديزل و استئجار المولدات و التنظيف و تقدر هذه التكاليف تقريبا ١٠١٣٤٠٨٦، رد الخبير: نوضح أنه من مهامنا فقط النظر في مدى استحقاق المدعي عليها في تسييل خطاب الضمان ذو المرجع (...) وعلى ذلك لا علاقة لنا فيما هو خالف ذلك، ثانيا: ملاحظات المدعية على تقرير الخبير ورد الخبير/ ورد من المدعية بتاريخ ٠٣/١٢/١٤٤٥هـ، الموافق ٠٩/٠٦/٢٠٢٤م، خطاب مكون من صفحتان يعرض جميع ملاحظاته على التقرير المبدئي و كانت كما يلي: ١/ مخالفة الخبير و تجاوزه لقرار الندب الصادر من الدائرة القضائية، رد الخبير: نوضح للمدعي أنه لم يتم مخالفة ذلك حيث اقتصر التقرير على خطاب الضمان ذو الرقم المرجعي (...) و بما أن خطاب الضمان الغرض منه ضمان حسن أداء المدعي و مدى التزامه بأداء التزاماته المنوطة إلية بالتعاقد يجب الرجوع للعقد و للأعمال المنجزة و معرفة مدى إنجاز المدعي لتلك الأعمال و مدى فشله فيها لبيان مدى استحقاق المدعى عليها لتسييل الخطاب من عدمه و على ذلك لم نتجاوز المهام المكلفة لنا بل اجتزئ عملنا فقط عليها دون التطرق للأمور الأخرى، ٢/ عدم صحة ما قرره الخبير من أحقية المدعي عليها في جزء من خطاب الضمان البنكي، رد الخبير: تم البناء على تقرير الخبير السابق و الصادر له حكم من قبل المحكمة و ليس من المهام المنوطة إلي النظر في مدى صحته من عدمه، ٣/ استند الخبير في تقرير على أن التأخير في تسليم الأعمال راجع على المدعية فقط و حملها مسؤولية التقصيرية، رد الخبير: نوضح لكم أنه تم ذلك بناء على مدة العمل و أنه إلى تاريخه و بعد انتهاء مدة التعاقد لم تقم المدعية بإنهاء الأعمال المنوطة إليها و كذلك لم تقدم أي بينه على تمديد مدة المشروع أو تغيير في التعاقد فيما بينهما للنظر فيه، وفي جلسة ٢٠/١٢/١٤٤٥هـ، افتتحت هذه الجلسة، وفيها حضر الطرفان، وتشير الدائرة إلى ورود تقرير الخبير متضمناً ملاحظات الأطراف، وبسؤال الأطراف عما لديهم من إضافة أفاد وكيل المدعى عليها بتقديم مذكرة عبر طلبات القضية بتاريخ هذه الجلسة تضمنت تعقيب على تقرير الخبير ونصها ما يلي: (أولاً: إشارة إلى الجلسة المنعقدة في تاريخ ١٥/١٠/١٤٤٥هـ، حيث رأت الدائرة الموقرة حاجة القضية لندب جهة خبرة هندسية وذلك لدراسة مدى صحة تسييل المدعى عليها لخطاب الضمان البنكي محل الدعوى وفقًا لما ورد فيه وبيان النتيجة النهائية: أصحاب الفضيلة، أن الغاية من تعيين جهة الخبرة لدراسة صحة تسيل موكلتنا لخطام الضمان البنكي، وذلك ما توصل إليه الخبير في دراسته الشاملة، حيث أكد على صحة التسييل وتقصير وخطا المدعية في تنفيذ العمل مما يدعم موقف موكلتنا في هذه الدعوى المنظورة أمامكم،.ثانياً: أكد الخبير في تقريره على خطأ المدعية (شركة المركب الخليجي) وتأخرها في تنفيذ، وصحة موكلتي في فسخ العقد وتسيل الضمان: يؤكد التقرير عن صحة وصلاحية موكلتنا في تسيل خطاب الضمان، وكما اثبت وجود التأخير في المشروع وأن المدعية تأخرت (١٣٥) يوم وبموجب العقد فإن وبموجب العقد فإن موكلتنا تستحق غرامة تأخير مقدرة بنسبة (٠.١١١بالمئة) عن كل يوم من قيمة العقد على أن لا تتجاوز الغرامة ١٠بالمئة من قيمة العقد، فبذلك موكلتنا تستحق كامل الغرامة وقدرها بقيمة ٦،٢١٢،٠٠٥ ريال، والتأكيد في التقرير على أن المدعية لم تنفذ عملها على أكمل وجه وموكلتنا محقة في فسخ العقد،.ثالثاً: لوحظ عدم نظر الخبير فيما ترتب على ذلك من مبالغ تفوق قيمة الضمان بالأساس، ولم يضمن الخبير ذلك كله في النتيجة: (أ) ولم ينظر الخبير لتكلفة التعاقد مع المقاول الجديد، حيث أن قيمة فرق التعاقد مع المقاول الجديد، قدرها ٦،٩٦١،٨٣٤.٦٧ ريال إضافي وهو يمثل فرق قيمة التعاقد مع المقاول الجديد، حيث أن العقد الأساسي مع المدعية بقيمة ٦٢،١٢٠،٠٥٠ ريال والأعمال المنفذة من المدعية قدرها ١٩,٢٥٧,٢١٥ ريال بناء على التقرير وعليه يصبح المتبقي من الأعمال قدرها ٤٢,٨٦٢,٨٣٤.٥ ريال، وقيمة عقد المقاول الجديد قدرها ٤٩،٨٦٤،٠٣١.١٩، وعليه فإن موكلتنا اضطرت إلى دفع مبلغ إضافي قدره ٧,٠٠١,١٩٦ ريال إضافي عن العقد. بسبب التعاقد مع مقاول جديد لإكمال الأعمال(ب) قيمة الأعمال التي لم يتم تضمينها في مبلغ المقاول الجديد قدرها ١١،٦٣٥،٩٦٨.٨١ وهذه المبالغ اضطرت موكلتنا لخفضها من العقد القديم وذلك لتجاوز الميزانية الأصلية وسرعة إنجاز الأعمال.(ج)أخطاء في التنفيذ قامت به المدعية، اضطرت موكلتي لتعديلها تتمثل في مبالغ تتجاوز مبلغ وقدرة ٨٤٢،٨٧٦.٩٥ ريال.(د)تكاليف أخرى تكبدتها موكلتنا نتيجة لفسخ العقد مع المدعية ومن هذه التكاليف: خدمات إدارة المشروع وخدمات الإشراف وأمن الموقع والمياه والديزل واستئجار المولدات والتنظيف وتقدر هذه التكاليف تقريبًا ١٠،١٣٤،٠٨٦ ريال، رابعًا: الطلبات: وعليه، وبناًء على مجمل ما سبق ذكره أعلاه وفي مذكراتنا السابقة، نطلب من فضيلتكم الاتي: أولا رفض دعوى المدعية لعدم استحقاقها وفق ما تم بيانه. ثانيًا إلزام المدعية بتعويض موكلتنا عن أتعاب المحاماة قدرها (٣٥٣،٢٦٠) ريال. ثالثًا احتفاظ موكلتنا بحقها في المطالبة بالأضرار والخسائر في دعوى مستقلة.)، ثم تقدمت وكيلة المدعية بمذكرة عبر المحادثة ونصها ما يلي: (تم إصدار تقرير الخبير النهائي والمبين به أن ما تستحقه المدعى عليها من قيمة خطاب الضمان هو ١٩٢٥٧٢١ريال فقط وان باقي قيمة خطاب الضمان والبالغة ٤٢٨٦٢٨٤ريال تكون من حق المدعية كون أن إجمالي قيمة خطاب الضمان هي مبلغ وقدره ٦٢١٢٠٠٥ريال ، علما بان ما قرره الخبير من أحقية المدعى عليها في جزء من قيمة الخطاب غير صحيح وقمنا بتقديم اعتراض عليه، ما قدمته وتدعيه المدعى عليه من أضرار تخص العقد أو تعويضات أو حتى غرامات فهي تخرج عن نطاق الدعوى المحصور في خطاب ضمان وان العقد المحرر بين الطرفين حدد إلية التقاضي والاختصاص القضائي للنزاعات الخاصة بالتزامات كل طرف بالعقد.عليه نتمسك بما ورد بالدعوى.) وعليه رفعت الجلسة للاطلاع والدراسة، وفي جلسة ٢٥/٠١/١٤٤٦هــ، حضر في هذه الجلسة وكيل المدعي (...) المدونة بياناته سابقاً وحضر وكيل المدعى عليها (...) المدونة بياناته سابقاً ولمزيد من الدراسة جرى رفع الجلسة، وفي جلسة ٠١/٠٣/١٤٤٦هـ، حضر الطرفان، وتشير الدائرة إلى قيامها بتوجيه استفسار إلى الخبير عن طريق منصة خبرة وورود جوابه جزئياً فتم إعادة الاستفسار الذي لم يقم بالجواب عليه ولم ترد الإفادة، وللتواصل مع الخبير جرى رفع الجلسة، وفي جلسة ٠٨/٠٣/١٤٤٦هـ، حضر الطرفان، وتشير الدائرة إلى ورود إفادة الخبير على استفسار الدائرة عبر منصة خبرة ، ولصلاحية القضية للفصل فيها جرى رفع الجلسة لإصدار الحكم.<br><br>الأسباب:<br>وقد حصر المدعي وكالة طلبه في إلزام المدعى عليها بما يلي/ أولا: رد قيمة الضمان البنكي الصادر عن حسن الأعمال رقم (...) بمبلغ وقدره (٦,٢١٢,٠٠٥) ستة ملايين ومائتان واثنا عشر ألف ريال وخمس هللات الصادر من البنك (...). ثانياً: أتعاب محاماة بمبلغ وقدره (٦٢٠,٠٠٠) ريال ستمائة وعشرون ألف ريال.<br>وأجمل وكيل المدعى عليها جوابه بأن المدعية قصرت في أعمالها، و &lrm;أخفقت في الكثير من التزاماتها مع قيام المدعى عليها بإشعارها حول هذه الإخفاقات عدة مرات، و لم تنجز من الأعمال سوى ما نسبته (%۳۱) من العقد، وقد فشلت في تسليم المشروع بالتاريخ وتوقفت عن العمل، وقامت بالتلاعب في تقارير الأعمال، ولم توفر الأيادي العاملة المطلوبة، وبسبب عدم التزام المدعية بتنفيذ الأعمال على أكمل وجه، وعدم التزامها بالعقد، قامت المدعى عليها بتسييل هذا الضمان بقدر الضرر والخسائر التي تعرضت له.<br>وبناء على ما تقدم وبما أن المحكمة لمست الحاجة إلى ندب خبرة هندسية لدراسة مدى صحة تسييل المدعى عليها لخطاب الضمان البنكي المشار له أعلاه وفقًا لما ورد فيه وبيان النتيجة النهائية في ذلك بحسبان ما جاء في المادة ( ١١٠/١) من نظام الإثبات والتي نصت على أنه: للمحكمة -من تلقاء نفسها أو بناء على طلب أحد الخصوم- أن تقرر ندب خبير أو أكثر؛ لإبداء رأيه في المسائل الفنية التي يستلزمها الفصل في الدعوى. ، والذي انتهى في تقريريه النهائي إلى: استحقاق المدعي عليها بصرف جزء من خطاب الضمان و قيمته هي مبلغ و قدره فقط (١٩٢٥٧٢١) مليون و تسعمائة و خمس و عشرون ألفاً و سبعمائة و واحد و عشرون ريالاً سعودياً من خطاب الضمان ذو الرقم المرجعي (...) ، و الذي قيمته هي (٦٢١٢٠٠٥) ستة ملايين و مئتان و اثني عشر ألفا و خمس ريالات سعودي وأن باقي قيمة خطاب الضمان والبالغة (٤٢٨٦٢٨٤). ريال تكون من حق المدعية ، وحيث إن المحكمة وما لها من سلطة في تقرير الأمور وترجيحها، وهي الخبير الأساس في القضية، وباطلاعها على التقرير المبدئي والملاحظات الواردة عليه من المدعى عليها، وإجابة الخبير عنها في تقريره النهائي، فإنها والحال ما تبين ترى وجاهة ما خلص له الخبير وتنتهي إلى إمضاء التقرير الهندسي وتضفي عليه الاعتبار فيما قرره وما وصل إليه من نتيجة، مما تنتهي معه المحكمة إلى الحكم الوارد في المنطوق. وأما ما يتعلق بأتعاب الخبرة واستناداً للمادة الثانية والعشرون بعد المائة من نظام الإثبات والتي نصت على أنه: يتحمل الخصم الذي خسر المطالبة محل الخبرة المبلغ المقرر للخبرة، إلا إذا كانت الخسارة نسبية فيتحمل كل من الخصوم بقدر خسارته، وتبين المحكمة ذلك في الحكم الصادر في موضوع الدعوى. ، فإن المحكمة تمضي في إلزام المدعى عليها بدفع نسبتها من أتعاب الخبرة التي تكبدتها المدعية، مما تنتهي معه المحكمة إلى الحكم الوارد في المنطوق.<br>وأما عن أتعاب المحاماة، ولما كان الثابت قضاءً أن أتعاب الدعوى لا تستحق إلا بتحقق أركان الضرر الثلاثة: (الخطأ والضرر والعلاقة السببية)، وبتطبيق ذلك على الدعوى الماثلة، نجد أن الضرر لم يثبت، ولم تقدم المدعية ما يدل على تكبدها أتعاب المحاماة، ولما سبق بيانه فإن الدائرة ترى عدم تحقق شروط استحقاق الأتعاب في هذه الدعوى؛ مما تنتهي معه المحكمة للحكم الوارد بمنطوقه.<br><br>نص الحكم:<br>حكمت الدائرة بما يلي: أولاً/ إلزام المدعى عليهاشركة (...) تجاري رقم: (...) بأن تدفع للمدعية شركة (...) للتجارة والمقاولات سجل تجاري رقم: (...) مبلغاً قدره (٤.٢٨٦.٢٨٤) أربعة ملايين ومائتان وستة وثمانون ألفاً ومائتان وأربعة وثمانون ريالاً. ثانياً/ مبلغاً قدره (٧.٩٣٥) سبعة آلاف وتسعمائة وخمسة وثلاثون ريالاً عن أتعاب الخبرة. ثالثاً/ رفض طلب أتعاب المحاماة، والله الموفق، وصلى الله وسلم على نبينا محمد وعلى آله وصحبه أجمعين.</p>\r\n<p>&nbsp;</p>",
        "judgmentCourtName": "المحكمة التجارية",
        "judgmentCourtType": "Lawsuit",
        "judgmentCityName": "الدمام",
        "hasAppeal": false,
        "appealNumber": null,
        "appealDate": null,
        "appealHijriiDate": "",
        "appealFacts": null,
        "appealReasons": null,
        "appealRuling": null,
        "appealTextofRulling": null,
        "appealCourtName": null,
        "appealCityName": null,
        "exportDate": null,
        "isFavorite": false,
        "judgmentNarrationList": [],
        "hasHighlight": false,
        "highlightNotes": null
    },
    "errors": []
} 

---

## Assistant (Build · gpt-5.3-codex · 27.0s)

_Thinking:_



Amazing — this is exactly what we needed. You now have a usable case API.

- **List API**: `POST /Judgements/judgements-list` (paginated IDs)
- **Details API**: `GET /Judgements/get-details?id=...&lang=ar...` (full text in `judgmentTextofRulling`)

So yes, you can now automate end-to-end:

1. Pull pages from `judgements-list` and store `id`, `caseNumber`, metadata.
2. For each `id`, call `get-details`.
3. Strip HTML from `judgmentTextofRulling` to plain Arabic text.
4. Extract citations (`المادة ... من نظام ...`) from text.
5. Map citation -> your normalized regulation/article in DB (**positive**).
6. Retrieve top similar non-matching articles as **hard negatives**.
7. Save training triplets and train.

Training row shape:
```json
{
  "case_id": "tHmWFp...",
  "query": "full case text ...",
  "positive": "full text of cited article",
  "negative": "similar but not applicable article"
}
```

Important:
- Use only the API (not page scraping).
- Add a quick manual QA sample (200 rows) before full training.

If you want, I can now draft the 2 scripts for your repo:
1) API extractor (list + details -> raw JSONL)  
2) Triplet builder (citation mapping + negatives -> train JSONL)

---

