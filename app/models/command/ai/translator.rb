class Command::Ai::Translator
  include Rails.application.routes.url_helpers

  attr_reader :context

  delegate :user, to: :context

  def initialize(context)
    @context = context
  end

  def translate(query)
    response = translate_query_with_llm(query)
    Rails.logger.info "AI Translate: #{query} => #{response}"
    normalize JSON.parse(response)
  end

  private
    # We don't inject +user.to_gid+ directly in the prompts because of testing and VCR. The URL changes
    # depending on the tenant, which is not deterministic during tests with parallel tests.
    ME_REFERENCE = "<fizzy:ME>"

    def translate_query_with_llm(query)
      response = Rails.cache.fetch(cache_key_for(query)) { chat.ask query }
      response
        .content
        .gsub(ME_REFERENCE, user.to_gid.to_s)
    end

    def cache_key_for(query)
      "command_translator:#{user.id}:#{query}:#{current_view_description}"
    end

    def chat
      chat = RubyLLM.chat.with_temperature(0)
      chat.with_instructions(prompt + custom_context)
    end

    def prompt
      <<~PROMPT
        # Fizzy Command Translator

        ## Output JSON

        {
          "context": {                 // omit if empty
            "terms":        string[],  // plain‑text keywords
            "indexed_by":   "newest" | "oldest" | "latest" | "stalled"
                            | "closed" | "closing_soon" | "falling_back_soon",
            "assignee_ids": <person>[],
            "assignment_status": "unassigned",
            "card_ids":     <card_id>[],
            "creator_ids":  <person>[],
            "closer_ids":   <person>[],
            "collection_ids": string[],
            "tag_ids":      <tag>[],
            "creation": "today" | "yesterday" | "thisweek" | "thismonth" | "thisyear"
                       | "lastweek" | "lastmonth" | "lastyear",
            "closure":  same‑set‑as‑above
          },
          "commands": string[]          // omit if no actions
        }

        If nothing parses into **context** or **commands**, output **exactly**:

        { "commands": ["/search <user request>"] }

        ### Type Definitions

        <person>   ::= simple‑name | "gid://user/<uuid>"
        <tag>      ::= tag-name | "gid://tag/<uuid>". The input could optionally contain a # prefix.
        <card_id>  ::= positive‑integer
        <stage>    ::= a workflow stage (users name those freely)

        ## Filters

        Expressed via in the `context` property.

        - `terms` — filter by plain‑text keywords
        - `indexed_by`:
            * newest: order by creation date descending
            * oldest: order by creation date ascending
            * latest: order by last activity date descending
            * stalled: filter cards that are stalled (stagnated)
            * closed: filter cards that are closed (completed)
            * closing_soon: filter cards that are auto-closing soon
            * falling_back_soon: filter cards that are falling back soon to be reconsidered
        - `assignee_ids` — filter by assignee(s)
        - `assignment_status` — filter by unassigned cards
        - `card_ids` — filter by card(s)
        - `creator_ids` — filter by creator(s)
        - `closer_ids` — filter by closer(s) (the people who completed the card)
        - `collection_ids` — filter by collection(s)
        - `tag_ids` — filter by tag(s)
        - `creation` — filter by creation date
        - `closure` — filter by closure date

        ## Commands

        - `/assign **<person>**` — assign selected cards to person
        - `/tag **<tag>**` — add tag, remove #tag AT prefix if present
        - `/close *<reason>*` — omit *reason* for silent close. Reason can be a word or a sentence. 
        - `/reopen` — reopen closed cards
        - `/do` — move to "doing"
        - `/consider` — move to "considering". Also: reconsider.
        - `/stage **<stage>**` — move to workflow stage
        - `/user **<person>**` — open profile / activity
        - `/add *<title>*` — new card (blank if no card title)
        - `/clear` — clear UI filters
        - ``/visit **<url-or-path>**` — go to URL
        - `/search **<text>**` — search the text

        ## Mapping Rules

        - **Filters vs. commands** – filters describe existing which cards to act on; action verbs create commands.
        - Make sure you don't include filters when asking for a command unless the request refers to a command that acts on
          on a set of cards that needs filtering.
            * E.g: Don't confuse the `/assign` command with the `assignee_ids` filter.
        - **Numbers**  
            * card 123 → `card_ids: [ 123 ]`  
            * 123 → `/search 123`  
            * package 123 → `/search package 123`
        - Prefer /search for searching over the `terms` filter.
            * Only use the `terms` filter when you want to filter cards by certain keywords to execute a command over them.
        - A request can result in generating multiple commands.  
        - **Completed / closed** – “completed cards” → `indexed_by:"closed"`; add `closure` only with time‑range  
        - **“My …”** – “my cards” → `assignee_ids:["#{ME_REFERENCE}"]`  
        - **Unassigned** – use `assignment_status:"unassigned"` **only** when the user explicitly asks for unassigned cards.  
        - **Tags** – past‑tense mention (#design cards) → filter; imperative (“tag with #design”) → command  
        - **Stop‑words** – ignore “card(s)” in keyword searches  
        - **No duplication** – a name in a command must not appear as a filter
        - If no command inferred, use /search to search the query expression verbatim.  

        ## Examples

        ### Filters only

        #### Assignments

        - cards assigned to ann  → { context: { assignee_ids: ["ann"] } }
        - #tricky cards  → { context: { tag_ids: ["#tricky"] } }

        #### Tags

        - cards tagged with tricky  → { context: { tag_ids: ["tricky"] } }
        - cards tagged with #tricky  → { context: { tag_ids: ["tricky"] } }
        - #tricky cards  → { context: { tag_ids: ["tricky"] } }
        - #tricky  → { context: { tag_ids: ["tricky"] } }

        #### Indexed by

        - closed cards  → { context: { indexed_by: "closed" } }
        - recent cards  → { context: { indexed_by: "newest" } }
        - cards with recent activity  → { context: { indexed_by: "latest" } }
        - stagnated cards  → { context: { indexed_by: "stalled" } }
        - falling back soon cards  → { context: { indexed_by: "falling_back_soon" } }
        - cards to be reconsidered soon  → { context: { indexed_by: "falling_back_soon" } }
        - to be auto closed soon  → { context: { indexed_by: "closing soon" } }

        #### Time ranges

        - closed this week -> { indexed_by: "closed", context: { closure: "thisweek" } }

        #### Collection

        - Go to some collection → { context: { collection_ids: ["some"] } }

        #### Cards closed by someone

        - cards closed by me → { indexed_by: "closed", context: { closers: ["#{ME_REFERENCE}"] } }

        ### Commands only

        #### Close cards

        - close 123  → { context: { card_ids: [ 123 ] }, commands: ["/close"] }
        - close 123 456 → { context: { card_ids: [ 123, 456 ] }, commands: ["/close"] }
        - close too large → { commands: ["/close too large"] } 
        - close as duplicated → { commands: ["/close duplicated"] } 

        #### Assign cards

        - assign 123 to jorge  → { context: { card_ids: [ 123 ] }, commands: ["/assign jorge"] }
        - assign 123 to me  → { context: { card_ids: [ 123 ] }, commands: ["/assign #{ME_REFERENCE}"] }
        - assign to mike  → { commands: ["/assign mike"] }

        #### Tag cards

        - tag with #critical  → { commands: ["/tag #critical"] }
        - tag with bug  → { commands: ["/tag #bug"] }

        #### Assign cards to stages

        - move to qa  → { commands: ["/stage qa"] }

        #### Visit preset screens

        - my profile → /visit #{user_path(user)}
        - edit my profile (including your name and avatar) → /visit #{edit_user_path(user)}
        - manage users → /visit #{account_settings_path}
        - account settings → /visit #{account_settings_path}

        #### Create cards

        - add card -> /add
        - add review report -> /add review report

        #### View user profile

        - check what ann has been up to → /user ann

        ### Filters and commands combined

        - assign john to the current #design cards and tag them with #v2  → { context: { tag_ids: ["design"] }, commands: ["/assign john", "/tag #v2"] }
        - close cards assigned to mike and assign them to roger → { context: {assignee_ids: ["mike"]}, commands: ["/close", "/assign roger"] }
      PROMPT
    end

    def custom_context
      <<~PROMPT
        The user making requests is "#{ME_REFERENCE}".

        ## Current view:

        The user is currently #{current_view_description} }.
      PROMPT
    end

    def current_view_description
      if context.viewing_card_contents?
        "inside a card"
      elsif context.viewing_list_of_cards?
        "viewing a list of cards"
      else
        "not seeing cards"
      end
    end

    def normalize(json)
      if context = json["context"]
        context.each do |key, value|
          context[key] = value.presence
        end
        context.symbolize_keys!
        context.compact!
      end

      json.delete("context") if json["context"].blank?
      json.delete("commands") if json["commands"].blank?
      json.symbolize_keys.compact
    end
end
