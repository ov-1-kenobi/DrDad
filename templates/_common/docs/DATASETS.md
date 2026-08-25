# Datasets

<!-- The SCHEMA LEDGER for the data this project charts, reports on, or computes from. The counterpart to
     SOURCES.md: that one records where DOCUMENTS came from, this one records what the DATA is supposed to
     look like. `dad data-stats` checks the real files against what you declare here and FAILS on any
     mismatch.

     Why it exists: a column can disappear, a unit can change from kg to lb, a scrape can return 3 rows
     instead of 300 - and the code still compiles, the tests still pass, and every gate stays green. A
     chart drawn from that data is confidently wrong, which is worse than one that is obviously broken.

     IT CHECKS SHAPE, NOT TRUTH. A harvest of 40 kg recorded as 400 passes every check here if 400 is
     inside the declared range. Declaring a tight, honest range is how you narrow that gap - and if a
     value's correctness really matters, it needs a test, not a schema.

     Cite the source of a dataset with [Snnn] from SOURCES.md in its "Where it comes from" note, so a
     number on a page traces back to a document the same way a claim does. -->

## D001: <dataset-name>
- **File:** `data/<name>.csv`
- **Key:** <column, or col1+col2 - used to detect duplicate rows; omit if rows are not unique>
- **Min rows:** 1
- **Where it comes from:** <how it is produced or collected; cite [Snnn] if a source document defines it>
- **Columns:**
  | column | type | required | range |
  |---|---|---|---|
  | <name> | text | yes | |

<!-- types    : text | number | integer | date | bool
     range    : `lo..hi` for numbers and dates, or `a;b;c` for an allowed-value set.
                SEMICOLONS, not pipes - the range sits in a markdown table cell and a pipe would end it.
                Leave blank for no constraint.
     required : yes -> an empty value is a FAIL. no -> empty is allowed, but a NON-empty value is still
                type- and range-checked.

     Checks `dad data-stats` performs:
       FAIL  the declared file is missing
       FAIL  a declared column is absent from the file        (every chart using it renders empty)
       FAIL  a required column has an empty value
       FAIL  a value is the wrong type, or outside its range / allowed set
       FAIL  fewer rows than "Min rows"                       (a partial load looks exactly like this)
       FAIL  duplicate Key values
       WARN  a column in the file that nobody declared        (drift - add it here, or drop it)   -->
