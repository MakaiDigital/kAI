# Writing for people

People must judge Kai's specs, plans, ADRs, evidence, pull request descriptions, review findings, replies, and reports quickly. Write them in ASD-STE100 (Simplified Technical English, the controlled language of aerospace maintenance manuals), to the degree that `KAI_WRITING_STE` in `.kai/config` sets.

- `KAI_WRITING_STE` is a percentage from 0 to 100. When it is missing or is not a whole number in that range, use 100.
- At 0, these rules are off.
- At 80, follow the rules below.
- At 100, follow the full ASD-STE100 specification, including its dictionary of approved words.
- Between these values, apply the rules more loosely or more strictly in proportion.

The rules:

- Put the result or the decision first. Put the detail after it.
- Write one idea in each sentence. Use at most 20 words in a step and 25 words in other sentences.
- Use the active voice. Say who or what does the action.
- Write each instruction in the imperative, one instruction in each sentence.
- Use one term for one thing. Do not change words for variety. Spell out an acronym the first time you use it.
- Use plain words. Do not use idioms, filler, or hedges.
- Use lists and tables instead of long paragraphs. Write at most six sentences in a paragraph.

Do not change code, commands, file paths, quoted output, or EARS criteria. They have their own fixed form.
