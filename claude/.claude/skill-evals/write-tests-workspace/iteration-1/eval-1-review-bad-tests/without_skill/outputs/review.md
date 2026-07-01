# Review: Contact Model Spec

## Problems Found

### 1. Tautological `#full_name` test (most critical issue)

```ruby
describe '#full_name' do
  it 'returns the full name' do
    contact = create(:contact, first_name: 'Jane', last_name: 'Smith')
    expected = "#{contact.first_name} #{contact.last_name}"
    expect(contact.full_name).to eq(expected)
  end
end
```

This test cannot fail. The expected value is derived from the same object it tests, so if `full_name` returned `contact.last_name` alone or `"#{contact.last_name} #{contact.first_name}"`, the test would still pass — because `expected` is just reading back the attributes that were set. Hard-code the expected string: `"Jane Smith"`.

Additionally, the test is **incomplete** given the documented behavior: `full_name` concatenates `first_name`, `middle_name` (optional), and `last_name`. The test covers only one case (no middle name) and never tests the middle name path at all.

### 2. `have_db_column` is low-value schema assertion

```ruby
it { is_expected.to have_db_column(:email).of_type(:string) }
```

This mirrors the database schema, not behavior. It will break on benign schema changes (e.g., changing `:string` to `:text` or `:citext`) with zero behavioral regression. Schema integrity is better enforced via migrations and schema.rb; model specs should test behavior. Remove this.

### 3. `respond_to` test tests Ruby plumbing, not behavior

```ruby
it { expect(contact).to respond_to(:archive!) }
```

This just checks the method exists. It tells you nothing about what `archive!` does. Replace with a test that exercises the method and asserts on observable state (e.g., the contact is archived, a flag is set, a timestamp changes).

### 4. `callback` matcher tests implementation, not behavior

```ruby
it { expect(contact).to callback(:update_search_index).after(:save) }
```

This pins the test to the internal callback mechanism. If `update_search_index` were moved to an `after_commit`, an observer, or a job, this test would fail even though behavior is unchanged. Test the observable outcome of saving (e.g., the search index is updated, or if that is a side effect, at minimum test via an integration path). If you must unit-test the callback exists, note that this test does not verify the callback fires correctly for relevant state changes vs. irrelevant ones.

### 5. Missing subject for `is_expected` matchers

```ruby
let(:contact) { create(:contact) }
it { is_expected.to have_many(:tasks) }
```

`is_expected` uses the implicit `subject`, which defaults to `described_class.new` (an unpersisted instance). The `let(:contact)` is defined but unused for these matchers. This is harmless for `have_many` (which is class-level), but it is confusing. Association matchers should use the class as the implicit subject or be explicit.

### 6. Missing edge cases for `#full_name`

The spec context says `middle_name` is optional. There are at least two behaviors to specify:
- With no middle name: `"Jane Smith"`
- With a middle name: `"Jane Marie Smith"` (or whatever the separator is)

The original spec has zero coverage of the middle name branch.

---

## Summary of Issues

| # | Issue | Severity |
|---|-------|----------|
| 1 | Tautological expected value in `#full_name` | Critical |
| 2 | Missing middle_name test coverage | High |
| 3 | `have_db_column` tests schema, not behavior | Medium |
| 4 | `respond_to` tests existence, not behavior | Medium |
| 5 | `callback` matcher tests implementation detail | Medium |
| 6 | Confusing implicit subject vs explicit `let` | Low |
