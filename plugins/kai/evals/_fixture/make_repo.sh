# Builds the eval fixture: a tiny Node "product favorites" service with Kai configured.
# Usage (from a case's scaffold.sh, run in the empty workspace): make_repo <variant> [level]
# Variants: plain (no kai), fresh, level2, build, prove, accept (prove, merged, with a spec)

make_repo() {
  variant=$1
  git init -q -b main
  git config user.email eval@example.com
  git config user.name "Eval Runner"
  git config commit.gpgsign false
  mkdir -p src test
  printf '{ "name": "shop", "private": true, "scripts": { "test": "node --test" } }\n' >package.json
  cat >src/favorites.js <<'EOF'
const favorites = new Map();

function addFavorite(userId, productId) {
  if (!userId) throw new Error("sign in required");
  const set = favorites.get(userId) ?? new Set();
  set.add(productId);
  favorites.set(userId, set);
}

function listFavorites(userId) {
  return [...(favorites.get(userId) ?? [])];
}

function reset() {
  favorites.clear();
}

module.exports = { addFavorite, listFavorites, reset };
EOF
  cat >test/favorites.test.js <<'EOF'
const test = require("node:test");
const assert = require("node:assert");
const favorites = require("../src/favorites");

test.beforeEach(() => favorites.reset());

test("adds_favorite_for_signed_in_user", () => {
  favorites.addFavorite("g1", "x1");
  assert.deepStrictEqual(favorites.listFavorites("g1"), ["x1"]);
});

test("rejects_add_when_signed_out", () => {
  assert.throws(() => favorites.addFavorite(null, "x1"));
});
EOF
  if [ "$variant" != plain ]; then
    level=${2:-1}
    [ "$variant" != level2 ] || level=2
    mkdir -p .kai
    cat >.kai/config <<EOF
KAI_LEVEL=$level
KAI_TICKET_PROVIDER=jira
KAI_TICKET_PREFIXES="PAY"
KAI_VERIFY_CMDS='node --test'
EOF
    printf 'specs/* low\ndocs/* low\n*.md low\n' >.kai/tiers
    cat >CLAUDE.md <<'EOF'
# shop

## How we deliver (Kai)

- Every change is keyed to a ticket; branch names contain the key. Artifacts live in `specs/<KEY>/`.
- Start with `/kai:spec <KEY>`, build with `/kai:build`, and finish with `/kai:prove`.
- "Done" means `kai verify` passed and its output is in `specs/<KEY>/evidence.md`.
EOF
  fi
  git add -A && git commit -qm "Initial app"

  case $variant in
    level2) ;;
    build)
      git switch -qc PAY-102-remove-favorite
      ;;
    prove | accept)
      git switch -qc PAY-103-remove-favorite
      mkdir -p specs/PAY-103
      cat >specs/PAY-103/plan.md <<'EOF'
# Plan: PAY-103 Remove a product from favorites

- **Spec:** PAY-103
- **Status:** Approved
- **Approved by:** Sam (engineering)

## Summary

Add `removeFavorite(userId, productId)` next to `addFavorite`, with the same sign-in check.

## Files touched

| Path | Change | Why |
|---|---|---|
| `src/favorites.js` | modify | add removeFavorite |
| `test/favorites.test.js` | modify | tests below |

## Tasks

1. Add removeFavorite and its tests.

## Tests

| Criterion | Test | File |
|---|---|---|
| Outcome: shopper can remove | `removes_favorite_for_signed_in_user` | `test/favorites.test.js` |
| Outcome: removal is safe | `remove_is_noop_when_not_favorited` | `test/favorites.test.js` |
| Constraint: signed out | `rejects_remove_when_signed_out` | `test/favorites.test.js` |

## Risks

None significant; in-memory only.
EOF
      git add -A && git commit -qm "PAY-103: plan"
      sed -i.bak 's/^function listFavorites/function removeFavorite(userId, productId) {\
  if (!userId) throw new Error("sign in required");\
  favorites.get(userId)?.delete(productId);\
}\
\
function listFavorites/; s/{ addFavorite, listFavorites, reset }/{ addFavorite, removeFavorite, listFavorites, reset }/' src/favorites.js
      rm src/favorites.js.bak
      cat >>test/favorites.test.js <<'EOF'

test("removes_favorite_for_signed_in_user", () => {
  favorites.addFavorite("g1", "x1");
  favorites.removeFavorite("g1", "x1");
  assert.deepStrictEqual(favorites.listFavorites("g1"), []);
});

test("remove_is_noop_when_not_favorited", () => {
  favorites.removeFavorite("g1", "x9");
  assert.deepStrictEqual(favorites.listFavorites("g1"), []);
});
EOF
      git add -A && git commit -qm "PAY-103: implement removeFavorite"
      if [ "$variant" = accept ]; then
        cat >specs/PAY-103/spec.md <<'EOF'
# Spec: PAY-103 Remove a product from favorites

- **Ticket:** PAY-103
- **Tier:** medium
- **Status:** Approved

## Criteria

- **C1** When a signed-in shopper removes a favorited product, the system shall no longer list it in their favorites.
- **C2** If a signed-out shopper tries to remove a favorite, then the system shall refuse with "sign in required" and change nothing.

## End-to-end verification

1. Save and remove a favorite: `node -e 'const f=require("./src/favorites"); f.addFavorite("g1","x1"); f.removeFavorite("g1","x1"); console.log(JSON.stringify(f.listFavorites("g1")))'` prints `[]`.
2. Signed-out removal is refused: `node -e 'const f=require("./src/favorites"); try { f.removeFavorite(null,"x1") } catch (e) { console.log(e.message) }'` prints `sign in required`.

## Contract

| Criterion | Test | Status | Evidence |
|---|---|---|---|
| C1 | `removes_favorite_for_signed_in_user` | PASS | evidence.md |
| C2 | `rejects_remove_when_signed_out` | PASS | evidence.md |
EOF
        git add -A && git commit -qm "PAY-103: spec and evidence"
        git switch -q main && git merge -q --no-ff -m "Merge PAY-103: remove a product from favorites" PAY-103-remove-favorite
      fi
      ;;
  esac
}
