# FOCO-126: Fix contact_inboxes.source_id for WhatsApp LID contacts
# This UPDATE is idempotent — once source_ids are corrected it matches no rows.
# Safe to leave in place; delete after confirming outgoing messages work.
begin
  updated = ActiveRecord::Base.connection.execute(<<~SQL).cmd_tuples
    UPDATE contact_inboxes ci
    SET source_id = c.identifier
    FROM contacts c,
         inboxes i
    WHERE ci.contact_id = c.id
      AND ci.inbox_id = i.id
      AND c.identifier LIKE '%@lid'
      AND ci.source_id = split_part(c.identifier, '@', 1)
      AND i.channel_type = 'Channel::Whatsapp'
      AND ci.source_id NOT LIKE '%@%'
  SQL
  Rails.logger.info "[FOCO-126] LID source_id migration: #{updated} contact_inbox(es) updated" if updated > 0
rescue => e
  Rails.logger.error "[FOCO-126] LID source_id migration failed: #{e.message}"
end
