# frozen_string_literal: true

class Views::Billing::TransferShow < Views::Base
  include Components::Shared::BillingHelpers

  def initialize(transfer:)
    @transfer = transfer
    @entries = transfer.ledger_entries.order(:id)
    @profile = transfer.billing_profile
  end

  def view_template
    render Components::Shared::PageToolbar.new(
      title: @transfer.idempotency_key,
      jumpcode_path: transfer_show_billing_index_path(key: @transfer.idempotency_key),
    )

    transfer_header
    transfer_timeline
    linked_entries
    linked_ledgerables
    raw_metadata if @transfer.metadata.present? && @transfer.metadata.any?
  end

  private

  # ── Transfer header ────────────────────────────────────

  def transfer_header
    section(class: "mb-1h") do
      div(class: "detail-grid") do
        span(class: "detail-label") { "State" }
        span { transfer_state_badge(@transfer) }

        span(class: "detail-label") { "Direction" }
        span do
          icon = @transfer.debit? ? "→" : "←"
          label = @transfer.debit? ? "debit (org → HQ)" : "credit (HQ → org)"
          plain "#{icon} #{label}"
        end

        span(class: "detail-label") { "Amount" }
        span(class: "fw-600 text-lg") { number_to_currency(@transfer.amount_cents / 100.0) }

        span(class: "detail-label") { "Organization" }
        span { strong { @profile.organization_name } }

        span(class: "detail-label") { "Linked by" }
        span(class: "text-muted") { @profile.user&.email || "—" }

        span(class: "detail-label") { "HQ org" }
        span { code { @transfer.hq_organization_id } }

        span(class: "detail-label") { "Name" }
        span { @transfer.name || "—" }

        if @transfer.remote_id.present?
          span(class: "detail-label") { "HCB remote ID" }
          span { code { @transfer.remote_id } }
        end

        span(class: "detail-label") { "Created" }
        span(class: "text-muted") { @transfer.created_at.strftime("%b %d, %Y %H:%M:%S") }

        if @transfer.last_attempted_at.present?
          span(class: "detail-label") { "Last attempt" }
          span(class: "text-muted") { @transfer.last_attempted_at.strftime("%b %d, %Y %H:%M:%S") }
        end

        if @transfer.memo.present?
          span(class: "detail-label") { "Memo" }
          span(class: "text-muted") { @transfer.memo }
        end
      end
    end
  end

  def transfer_state_badge(t)
    variant = case t.state
    when "completed" then "badge-success"
    when "pending" then "badge-warning"
    when "unknown" then "badge-danger"
    when "failed" then "badge-danger"
    end

    span(class: "badge #{variant}") { t.state }

    if t.gave_up?
      plain " "
      span(class: "badge badge-danger") { "gave up" }
    elsif t.retryable?
      plain " "
      span(class: "badge badge-warning") { "retryable" }
    elsif t.abandoned?
      plain " "
      span(class: "badge") { "abandoned" }
    end
  end

  # ── Attempt timeline ───────────────────────────────────

  def transfer_timeline
    return unless @transfer.attempts > 0 || @transfer.last_error.present?

    section(class: "mb-1h") do
      h3(class: "mt-0") { "Attempts" }

      div(class: "detail-grid") do
        span(class: "detail-label") { "Attempts" }
        span { "#{@transfer.attempts} / #{HCB::Transfer::MAX_ATTEMPTS}" }

        if @transfer.next_attempt_at.present?
          span(class: "detail-label") { "Next attempt" }
          span { @transfer.next_attempt_at.strftime("%b %d, %Y %H:%M") }
        end

        if @transfer.last_error.present?
          span(class: "detail-label") { "Last error" }
          span(class: "text-muted") do
            pre(class: "code-block") { @transfer.last_error }
          end
        end

        nsf = @transfer.metadata["nsf"]
        if nsf
          span(class: "detail-label") { "NSF" }
          span { span(class: "badge badge-danger") { "insufficient funds" } }
        end
      end

      if @transfer.failed? || @transfer.unknown?
        div(class: "mt-half") do
          retry_form
        end
      end
    end
  end

  def retry_form
    return if @entries.pending.none?

    form(action: retry_transfer_billing_index_path(transfer_id: @transfer.id), method: "post", class: "form-inline") do
      input(type: "hidden", name: "authenticity_token", value: helpers.form_authenticity_token)
      if @transfer.unknown?
        input(type: "hidden", name: "force", value: "1")
        button(type: "submit", class: "btn-sm btn-danger", data: { turbo_confirm: force_retry_confirm }) { "Force retry (may double charge)" }
      else
        button(type: "submit", class: "btn-sm btn-warning") { "Retry now" }
      end
    end
  end

  # ── Linked ledger entries ──────────────────────────────

  def linked_entries
    section(class: "mb-1h") do
      h3(class: "mt-0") { "Ledger Entries (#{@entries.size})" }

      if @entries.any?
        table do
          thead do
            tr do
              th { "" }
              th { "Category" }
              th(class: "text-right") { "Amount" }
              th(class: "text-right") { "Net" }
              th { "State" }
              th { "For" }
              th { "Credits" }
            end
          end
          tbody do
            @entries.each do |entry|
              tr do
                td { a(href: billing_path(entry), class: "no-underline text-muted") { "LE##{entry.id}" } }
                td { span(class: "badge badge-info") { entry.category } }
                td(class: "text-right fw-600#{entry.credit? ? " text-success" : ""}") { number_to_currency(entry.amount_cents / 100.0) }
                td(class: "text-right") do
                  net = entry.net_cents
                  if net != entry.amount_cents
                    span(class: "text-muted") { number_to_currency(net / 100.0) }
                  else
                    span(class: "text-muted") { "—" }
                  end
                end
                td { state_badge(entry.state) }
                td { ledgerable_link(entry) }
                td do
                  if entry.reversals.any?
                    entry.reversals.each do |credit|
                      a(href: billing_path(credit), class: "text-success no-underline") { number_to_currency(credit.amount_cents / 100.0) }
                      plain " "
                    end
                  else
                    span(class: "text-muted") { "—" }
                  end
                end
              end
            end
          end
        end

        totals_row
      else
        p(class: "text-muted") { "No ledger entries linked to this transfer." }
      end
    end
  end

  def totals_row
    total = @entries.sum(&:amount_cents)
    net = @entries.sum(&:net_cents)

    div(class: "mt-half text-muted") do
      plain "Total: #{number_to_currency(total / 100.0)}"
      if net != total
        plain " · Net: #{number_to_currency(net / 100.0)}"
      end
    end
  end

  # ── What the money paid for ────────────────────────────

  def linked_ledgerables
    ledgerables = @entries.filter_map(&:ledgerable).uniq
    return if ledgerables.empty?

    section(class: "mb-1h") do
      h3(class: "mt-0") { "Paid for" }

      ledgerables.each do |obj|
        case obj
        when Batch
          batch_card(obj)
        when Warehouse::Order
          order_card(obj)
        when USPS::Indicium
          indicium_card(obj)
        else
          div(class: "mb-half") do
            plain "#{obj.class.name.demodulize} ##{obj.id}"
          end
        end
      end
    end
  end

  def batch_card(batch)
    div(class: "mb-half") do
      a(href: letter_batch_path(batch), class: "no-underline") do
        strong { "Letter Batch #{batch.public_id}" }
      end
      plain " · #{batch.letters.size} letters · #{batch.aasm_state}"
    end
  end

  def order_card(order)
    div(class: "mb-half") do
      a(href: warehouse_order_path(order), class: "no-underline") do
        strong { order.user_facing_title || "Warehouse Order" }
      end
      plain " · #{order.hc_id || "Order ##{order.id}"} · #{order.aasm_state}"
    end
  end

  def indicium_card(indicium)
    div(class: "mb-half") do
      if indicium.letter.present?
        a(href: letter_path(indicium.letter), class: "no-underline") do
          strong { "Indicium #{indicium.public_id}" }
        end
        plain " → Letter #{indicium.letter.public_id}"
      else
        strong { "Indicium #{indicium.public_id}" }
      end
    end
  end

  # ── Raw metadata ───────────────────────────────────────

  def raw_metadata
    section do
      h3(class: "mt-0") { "Metadata" }
      pre(class: "code-block") { JSON.pretty_generate(@transfer.metadata) }
    end
  end

  # ── Helpers ────────────────────────────────────────────

  def force_retry_confirm
    "This transfer is UNKNOWN: it may ALREADY have landed on HCB. " \
    "HCB cannot de-duplicate it, so retrying can charge " \
    "#{@profile.organization_name} #{number_to_currency(@transfer.amount_cents / 100.0)} a second time. " \
    "Only continue if you have checked HCB by hand and this transfer is NOT there."
  end
end
