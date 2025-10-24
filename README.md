# Planova

A future proof opinionated software written with flutter to manage your life in plaintext : todo, agenda, journal and notes.

By using a more structured yet flexible approach with dailies Markdown files instead of a calendar.txt and todo.txt, Planova provides a more efficient, scalable, and user-friendly experience compared to MOrg.

## File structure

- Org
  - dailies/
    - 20250128.md
    - 20250129.md
  - archives/
  - notes/
    - Work/
      - project_1.md
    - Personnal/
      - project_2.md
    - OtherSubFolder/
      - notes_can_be_stored_in_subfolder.md

## Roadmap

- [x] Main View
  - [x] Display a month calendar with in a scrollview and below the content markdown of the current selected day
  - [x] Editable content
  - [x] Check/Uncheck todo on double click/tap
- [x] Notes View : A list view of all notes
  - [x] Add note button
  - [x] Rename a note
  - [ ] Archive a note
  - [ ] folding notes sub folder
  - [x] search
  - [ ] Share a note 
- [x] Implement preferences screen
  - [x] theme selection
- [ ] Receive android intent
