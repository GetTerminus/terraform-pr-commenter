# Changelog

## v3.0.0
- Add support for tflint.
- Remove requirement to run `terraform show` internally and depend on either direct input or directing the `terraform plan` output to a txt file.
- Add support for adding partial plan to the comment on failure.

## v2.0.0
- Run `terraform show` internally to bypass github 64k limit.
- Paginate comments that are greater than 64k characters and delete corresponding paginated comments on each successive rerun.
- Temporarily swap out red `-` so yaml arrays aren't confused with diff-removal lines.

## v1.5.0

- Bump to Terraform v1.0.6 internally (only affects `fmt`)
- Fix Terraform v1 `plan` output truncation

## v1.4.0

- Bump to Terraform v0.15.0 internally (only affects `fmt`)
- Change the way `plan`s are truncated after introduction of new horizontal break in TF v0.15.0
- Add `validate` comment handling
- Update readme

## v1.3.0

- Bump to Terraform v0.14.9 internally (only affects `fmt`)
- Fix output truncation in Terraform v0.14 and above

## v1.2.0

- Bump to Terraform v0.14.5 internally (only affects `fmt`)
- Change to leave `fmt` output as-is
- Add colourisation to `plan` diffs where there are changes (on by default, controlled with `HIGHLIGHT_CHANGES` environment variable)
- Update readme

## v1.1.0

- Adds better parsing for Terraform v0.14

## v1.0.0

- Initial release.
