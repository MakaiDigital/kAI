---
type: regex
target:
  source: file
  path: test/favorites.test.js
pattern: '(?=[\s\S]*removes_favorite_for_signed_in_user)(?=[\s\S]*remove_is_noop_when_not_favorited)(?=[\s\S]*rejects_remove_when_signed_out)'
---
