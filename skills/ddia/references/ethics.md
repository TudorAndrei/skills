# Ethics of Data Systems

Covers DDIA 2nd ed., Chapter 14 (Doing the Right Thing).

## Stance

- Engineers own the consequences of what their systems do to people, intended or not. "The algorithm decided" is not an excuse.
- Many datasets describe people. Treat that data with respect for their dignity.
- Ethics is not a compliance checklist. It is ongoing reflection with the affected people, with accountability for outcomes. The checklist below starts that conversation; it does not end it.

## Predictive analytics and automated decisions

- Predicting weather is different from predicting whether a person will default, reoffend, or claim. Decisions about individuals need extra scrutiny.
- Asymmetric incentives: organisations lose little by saying no, so models lean to rejection. A person wrongly flagged as risky gets rejected by many systems at once and can be shut out of jobs, credit, housing, travel, and insurance without proof and without appeal.
- Bias: models learn rules from data. Biased input yields biased, often amplified, output. Removing protected attributes is not enough, because proxies (postal code, IP address, etc.) encode them. Data-driven does not mean fair.
- Models extrapolate the past. If the past was discriminatory, the model makes that permanent. Improving on the past needs human judgment.
- Statistical output is right on average and can be wrong for any individual.
- Opaque models over broad inputs judge people by who they resemble, not by what they did. Recourse is very hard when the input data is wrong.
- The same analytics can target help to vulnerable people or target predatory products at them.

Rules:

- For any model that affects individuals: define who is accountable, how a decision is explained, how a person appeals, and how wrong input data is corrected.
- Test for disparate outcomes across groups, including through proxy features.
- Keep a human in the loop for high-impact decisions.

## Feedback loops

- Recommenders that optimise for predicted preference can create echo chambers that spread polarisation and misinformation.
- Decisions that feed their own inputs spiral (e.g., a low score reduces opportunity, which lowers the score further). Pricing algorithms can learn to collude.
- Use systems thinking: model the people around the software, not only the software. Ask whether the system widens or narrows existing gaps.

## Privacy, tracking, and surveillance

- Data a user enters for a service they asked for = service to the user. Behaviour logged as a side effect = the service serves its own interests, which can conflict with the user's.
- Some tracking directly improves features for the user (ranking from clicks, related products, A/B tests). Ad-funded models push tracking further: advertisers become the customer, profiles become detailed and long-retained. At that point it is surveillance.
- Test: replace "data" with "surveillance" in your design doc. If it reads badly, reconsider.
- Sensor data and analytics reveal more than expected (health, finances, even keystrokes from motion sensors). Decisions on insurance or employment from tracked behaviour stop being benign.

### Consent

- Consent is not meaningful when users cannot understand what is collected, how it is combined into derived datasets, or how long it is kept. Privacy policies usually obscure rather than explain.
- Data about one user often describes non-users who never agreed.
- The terms are one-sided and not negotiable. Opting out of a service people need for social or professional life is not a free choice, especially for less privileged people.
- GDPR-style consent must be freely given, specific, informed, unambiguous, revocable without penalty, and in plain language; silence or pre-ticked boxes do not count. Other lawful bases exist (legal obligation, vital interest, legitimate interest such as fraud prevention).

### What privacy means

- Privacy is the right to decide what to reveal, to whom, and for what purpose. It is not secrecy.
- Surveillance transfers that decision right from the person to the collector, who then exercises it for profit (e.g., ad targeting by sensitive attributes) while keeping the details hidden.
- User-facing privacy settings control other users' access, not the operator's own internal use.
- Expect data to be wrong, unwanted, or hurtful in context. Build ways to correct, suppress, and remove it.

## Data as a liability

- Personal data is a valuable asset, so others want it: attackers, insiders, buyers in bankruptcy, future management, governments by legal force or otherwise. Breaches are frequent.
- Treat stored personal data as hazardous material. Weigh every collection against the risk of it being misused under any future owner or government, not only today's.
- Accumulated knowledge about people is power held without scrutiny.

## Regulation and self-regulation

- Purpose limitation and data minimisation (collect for stated purposes, keep only what is needed) conflict with "collect everything, explore later". Exploration for unplanned purposes is exactly what these principles forbid.
- Over-regulation can block real benefits (e.g., medical research). Balance case by case.
- Do not wait for enforcement: treat users as people, not metrics; tell them how their data is used; leave them in control.

Rules:

- Collect the minimum. Do not keep data forever; purge it when the purpose ends. Data you do not hold cannot leak or be seized.
- Define a retention period and a deletion path for every personal-data store, including derived stores, logs, and backups (see crypto-shredding in stream-processing.md).

## Review checklist

- Does the system make or feed decisions about individuals? Who is accountable, and can affected people get an explanation, appeal, and data correction?
- Could any feature act as a proxy for a protected trait? Have outcomes been measured per group?
- Can outputs feed back into future inputs and amplify harm?
- Is each tracked field needed for a feature the user benefits from, or only for monetisation?
- Would users understand and agree to this collection and derivation if told plainly? Does it capture data about non-users?
- What is the purpose, retention period, and deletion mechanism for each personal-data store, including derived copies and backups?
- What happens if this data is breached, sold, subpoenaed, or used by a future owner with different values?
- Can users correct or suppress data that is wrong or hurtful?
