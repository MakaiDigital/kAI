make_repo() {
  variant=$1
  level=${2:-1}
  [ "$variant" != level2 ] || level=2
  template="$(dirname "$0")/../../template"
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
    mkdir -p .kai
    cat >.kai/config <<EOF
KAI_LEVEL=$level
KAI_TICKET_PROVIDER=jira
KAI_TICKET_PREFIXES="PAY"
KAI_VERIFY_CMDS='node --test'
EOF
    cp "$template/.kai/tiers" "$template/.kai/constraints.md" .kai/
    {
      printf '# shop\n\n%s\n' '<!-- kai:begin (managed by the kai installer; edit outside this block) -->'
      cat "$template/claude-block.md"
      printf '%s\n' '<!-- kai:end -->'
    } >CLAUDE.md
  fi
  git add -A && git commit -qm "Initial app"

  case $variant in
    build)
      git switch -qc PAY-102-remove-favorite
      ;;
    prove | accept)
      mkdir -p specs/PAY-103
      spec='none (ticket PAY-103)' c1='Outcome: shopper can remove' c2='Outcome: removal is safe' c3='Constraint: signed out'
      if [ "$level" -ge 2 ] || [ "$variant" = accept ]; then
        spec='[spec.md](spec.md)' c1=C1 c2=C2 c3=C3
        cat >specs/PAY-103/spec.md <<'EOF'
---
key: PAY-103
ticket: PAY-103
tier: medium
status: approved
adr: none
---

# Spec: PAY-103 Remove a product from favorites

## Review here

- Removing a product that is not a favorite does nothing rather than failing (C2; kept, decided by Priya, product).

## Context

- **Problem:** Shoppers can heart a product to save it but cannot remove it again.
- **Outcome:** A signed-in shopper can remove a product from their favorites, and it no longer appears in their list.
- **Success metric:** Support tickets about removing favorites drop to zero within a month of release.
- **Constraints:** Signed-out visitors cannot change favorites.
- **Out of scope:** Bulk removal, and keeping favorites across restarts.

## Criteria

- **C1** When a signed-in shopper removes a product from their favorites, the system shall no longer list it in their favorites.
- **C2** When a signed-in shopper removes a product that is not in their favorites, the system shall leave their favorites unchanged.
- **C3** If a signed-out shopper tries to remove a favorite, then the system shall refuse with "sign in required".

## Interfaces touched

The favorites service: a new remove operation next to add and list.

## End-to-end verification

1. Remove a favorite: `node -e 'const f=require("./src/favorites"); f.addFavorite("g1","x1"); f.removeFavorite("g1","x1"); console.log(JSON.stringify(f.listFavorites("g1")))'` prints `[]`.
2. Remove a product that is not a favorite: `node -e 'const f=require("./src/favorites"); f.addFavorite("g1","x1"); f.removeFavorite("g1","x9"); console.log(JSON.stringify(f.listFavorites("g1")))'` prints `["x1"]`.
3. Remove while signed out: `node -e 'const f=require("./src/favorites"); try { f.removeFavorite(null,"x1") } catch (e) { console.log(e.message) }'` prints `sign in required`.

## Security

Removal reuses the sign-in check that adding has (C3). No new data is stored.

## Contract

| Criterion | Test | Status | Evidence |
|---|---|---|---|
| C1 | `removes_favorite_for_signed_in_user` | FAIL | |
| C2 | `remove_is_noop_when_not_favorited` | FAIL | |
| C3 | `rejects_remove_when_signed_out` | FAIL | |
EOF
        git add -A && git commit -qm "PAY-103: spec"
      fi
      git switch -qc PAY-103-remove-favorite
      cat >specs/PAY-103/plan.md <<EOF
# Plan: PAY-103 Remove a product from favorites

- **Spec:** $spec
- **Status:** Approved
- **Approved by:** Sam (engineering)

## Summary

Add \`removeFavorite(userId, productId)\` next to \`addFavorite\`, with the same sign-in check.

## Files touched

| Path | Change | Why |
|---|---|---|
| \`src/favorites.js\` | modify | add removeFavorite |
| \`test/favorites.test.js\` | modify | tests below |

New files: none
New dependencies: none

## Tasks

1. Add removeFavorite and its tests.

## Tests

| Criterion | Test | File |
|---|---|---|
| $c1 | \`removes_favorite_for_signed_in_user\` | \`test/favorites.test.js\` |
| $c2 | \`remove_is_noop_when_not_favorited\` | \`test/favorites.test.js\` |
| $c3 | \`rejects_remove_when_signed_out\` | \`test/favorites.test.js\` |

## Risks

None significant; favorites live in memory. Roll back by reverting the change.

## Existing decisions relied on

None.

## Verification

\`kai verify\`.
EOF
      git add -A && git commit -qm "PAY-103: plan"
      cat >>test/favorites.test.js <<'EOF'

test("removes_favorite_for_signed_in_user", () => {
  favorites.addFavorite("g1", "x1");
  favorites.removeFavorite("g1", "x1");
  assert.deepStrictEqual(favorites.listFavorites("g1"), []);
});

test("remove_is_noop_when_not_favorited", () => {
  favorites.addFavorite("g1", "x1");
  favorites.removeFavorite("g1", "x9");
  assert.deepStrictEqual(favorites.listFavorites("g1"), ["x1"]);
});
EOF
      if [ "$variant" = accept ]; then
        cat >>test/favorites.test.js <<'EOF'

test("rejects_remove_when_signed_out", () => {
  assert.throws(() => favorites.removeFavorite(null, "x1"), /sign in required/);
});
EOF
      fi
      git add -A && git commit -qm "PAY-103: failing tests"
      sed -i.bak 's/^function listFavorites/function removeFavorite(userId, productId) {\
  if (!userId) throw new Error("sign in required");\
  favorites.get(userId)?.delete(productId);\
}\
\
function listFavorites/; s/{ addFavorite, listFavorites, reset }/{ addFavorite, removeFavorite, listFavorites, reset }/' src/favorites.js
      rm src/favorites.js.bak
      git add -A && git commit -qm "PAY-103: implement removeFavorite"
      if [ "$variant" = accept ]; then
        printf '# Evidence\n\nkai verify on commit %s at %s.\n' "$(git rev-parse HEAD)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >specs/PAY-103/evidence.md
        cat >>specs/PAY-103/evidence.md <<'EOF'

## PASS: node --test (exit 0)

~~~text
✔ adds_favorite_for_signed_in_user (1.125334ms)
✔ rejects_add_when_signed_out (0.25375ms)
✔ removes_favorite_for_signed_in_user (0.143541ms)
✔ remove_is_noop_when_not_favorited (0.0875ms)
✔ rejects_remove_when_signed_out (0.084917ms)
ℹ tests 5
ℹ suites 0
ℹ pass 5
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 55.966167
~~~

Result: **PASS**

## Planned tests

| Criterion | Test | Result | Output line |
|---|---|---|---|
| C1 | `removes_favorite_for_signed_in_user` | PASS | `✔ removes_favorite_for_signed_in_user (0.143541ms)` |
| C2 | `remove_is_noop_when_not_favorited` | PASS | `✔ remove_is_noop_when_not_favorited (0.0875ms)` |
| C3 | `rejects_remove_when_signed_out` | PASS | `✔ rejects_remove_when_signed_out (0.084917ms)` |
EOF
        sed -i.bak '/^| C[0-9] |/d' specs/PAY-103/spec.md
        rm specs/PAY-103/spec.md.bak
        cat >>specs/PAY-103/spec.md <<'EOF'
| C1 | `removes_favorite_for_signed_in_user` | PASS | `✔ removes_favorite_for_signed_in_user (0.143541ms)` |
| C2 | `remove_is_noop_when_not_favorited` | PASS | `✔ remove_is_noop_when_not_favorited (0.0875ms)` |
| C3 | `rejects_remove_when_signed_out` | PASS | `✔ rejects_remove_when_signed_out (0.084917ms)` |
EOF
        git add -A && git commit -qm "PAY-103: evidence"
        git switch -q main
        git merge -q --no-ff -m "Merge PAY-103: remove a product from favorites" PAY-103-remove-favorite
      fi
      ;;
  esac
  git init -q --bare -b main .git/origin.git
  git remote add origin .git/origin.git
  git push -q -u origin main
}
