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

- [ ] Main View
  - [ ] Display a month calendar with in a scrollview and below the content markdown of the current selected day
  - [ ] Editable content
  - [ ] Check/Uncheck todo on double click/tap
- [ ] Notes View : A list view of all notes
  - [ ] Add note button
  - [ ] Rename a note
  - [ ] Archive a note
  - [ ] folding notes sub folder
  - [ ] search
  - [ ] Share a note 
- [ ] Implement preferences screen
  - [ ] theme selection
- [ ] Receive android intent
