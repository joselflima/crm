SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: channel_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.channel_status AS ENUM (
    'pending',
    'connected',
    'error',
    'disabled'
);


--
-- Name: channel_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.channel_type AS ENUM (
    'whatsapp',
    'instagram'
);


--
-- Name: conversation_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.conversation_status AS ENUM (
    'bot',
    'queued',
    'assigned',
    'closed'
);


--
-- Name: message_direction; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.message_direction AS ENUM (
    'inbound',
    'outbound'
);


--
-- Name: message_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.message_status AS ENUM (
    'pending',
    'sent',
    'delivered',
    'read',
    'failed'
);


--
-- Name: sender_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sender_type AS ENUM (
    'contact',
    'ai',
    'agent',
    'system'
);


--
-- Name: tenant_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.tenant_status AS ENUM (
    'trial',
    'active',
    'past_due',
    'suspended',
    'canceled'
);


--
-- Name: user_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_role AS ENUM (
    'super_admin',
    'admin',
    'agent'
);


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin new.updated_at = now(); return new; end; $$;


--
-- Name: transfer_to_human(uuid, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.transfer_to_human(p_tenant_id uuid, p_conversation_id uuid, p_reason text DEFAULT 'user_request'::text, p_summary text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare v_conv public.conversations%rowtype;
begin
  update public.conversations
     set status         = 'queued',
         ai_paused      = true,
         handoff_reason = p_reason,
         summary        = coalesce(p_summary, summary),
         updated_at     = now()
   where id = p_conversation_id
     and tenant_id = p_tenant_id
     and status = 'bot'
  returning * into v_conv;

  if not found then
    return jsonb_build_object('ok', false, 'reason', 'NOT_IN_BOT_STATE');
  end if;

  insert into public.notifications (tenant_id, type, severity, title, body, link)
  values (p_tenant_id, 'new_lead', 'info', 'Novo lead na fila',
          coalesce(p_summary, 'Um lead pediu atendimento humano.'),
          '/inbox/' || p_conversation_id);

  return jsonb_build_object('ok', true, 'conversation_id', v_conv.id);
end; $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: channels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.channels (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    type public.channel_type NOT NULL,
    external_id text NOT NULL,
    display_name text NOT NULL,
    phone_number text,
    waba_id text,
    page_id text,
    access_token text,
    webhook_verified_at timestamp with time zone,
    status public.channel_status DEFAULT 'pending'::public.channel_status NOT NULL,
    last_error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contacts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    channel_id uuid NOT NULL,
    external_user_id text NOT NULL,
    name text,
    phone text,
    email text,
    avatar_url text,
    tags text[] DEFAULT '{}'::text[] NOT NULL,
    custom_fields jsonb DEFAULT '{}'::jsonb NOT NULL,
    notes text,
    is_blocked boolean DEFAULT false NOT NULL,
    first_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    last_message_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    channel_id uuid NOT NULL,
    status public.conversation_status DEFAULT 'bot'::public.conversation_status NOT NULL,
    assigned_to uuid,
    assigned_at timestamp with time zone,
    handoff_reason text,
    ai_paused boolean DEFAULT false NOT NULL,
    ai_turn_count integer DEFAULT 0 NOT NULL,
    summary text,
    billing_window_started_at timestamp with time zone,
    service_window_expires_at timestamp with time zone,
    last_message_at timestamp with time zone,
    last_inbound_at timestamp with time zone,
    last_outbound_at timestamp with time zone,
    unread_count integer DEFAULT 0 NOT NULL,
    closed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    conversation_id uuid NOT NULL,
    direction public.message_direction NOT NULL,
    sender_type public.sender_type NOT NULL,
    sender_id uuid,
    content_type text DEFAULT 'text'::text NOT NULL,
    content text,
    media_url text,
    media_mime text,
    media_size_bytes bigint,
    provider_message_id text,
    reply_to_id uuid,
    status public.message_status DEFAULT 'sent'::public.message_status NOT NULL,
    error_code text,
    error_message text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    delivered_at timestamp with time zone,
    read_at timestamp with time zone
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid NOT NULL,
    user_id uuid,
    type text NOT NULL,
    severity text DEFAULT 'info'::text NOT NULL,
    title text NOT NULL,
    body text,
    link text,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    price_cents integer DEFAULT 0 NOT NULL,
    currency text DEFAULT 'BRL'::text NOT NULL,
    max_users integer DEFAULT 3 NOT NULL,
    max_channels integer DEFAULT 1 NOT NULL,
    included_conversations integer DEFAULT 500 NOT NULL,
    overage_pack_size integer DEFAULT 500 NOT NULL,
    overage_pack_price_cents integer DEFAULT 19700 NOT NULL,
    allow_byok boolean DEFAULT false NOT NULL,
    features jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tenant_id uuid,
    role public.user_role DEFAULT 'agent'::public.user_role NOT NULL,
    full_name text,
    email text NOT NULL,
    password_hash text,
    avatar_url text,
    phone text,
    is_active boolean DEFAULT true NOT NULL,
    last_seen_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT profiles_super_admin_tenant_check CHECK ((((role = 'super_admin'::public.user_role) AND (tenant_id IS NULL)) OR ((role <> 'super_admin'::public.user_role) AND (tenant_id IS NOT NULL)))),
    CONSTRAINT profiles_tenant_required CHECK ((((role = 'super_admin'::public.user_role) AND (tenant_id IS NULL)) OR ((role <> 'super_admin'::public.user_role) AND (tenant_id IS NOT NULL))))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: tenant_secrets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_secrets (
    tenant_id uuid NOT NULL,
    openai_api_key text,
    anthropic_api_key text,
    meta_access_token text,
    meta_app_secret text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    whatsapp_access_token text,
    whatsapp_phone_number_id text,
    instagram_access_token text,
    instagram_business_account_id text
);


--
-- Name: tenant_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenant_settings (
    tenant_id uuid NOT NULL,
    ai_enabled boolean DEFAULT true NOT NULL,
    ai_provider text DEFAULT 'anthropic'::text NOT NULL,
    ai_model text DEFAULT 'claude-haiku-4-5-20251001'::text NOT NULL,
    ai_temperature numeric(3,2) DEFAULT 0.30 NOT NULL,
    ai_max_output_tokens integer DEFAULT 600 NOT NULL,
    system_prompt text DEFAULT ''::text NOT NULL,
    handoff_message text DEFAULT 'Só um momento, vou chamar um atendente para você.'::text NOT NULL,
    out_of_credits_message text DEFAULT 'Recebi sua mensagem! Um atendente vai responder em instantes.'::text NOT NULL,
    offline_message text,
    business_hours jsonb DEFAULT '{}'::jsonb NOT NULL,
    respect_business_hours boolean DEFAULT false NOT NULL,
    auto_assign_enabled boolean DEFAULT false NOT NULL,
    response_delay_seconds integer DEFAULT 3 NOT NULL,
    max_ai_turns integer DEFAULT 20 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tenants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tenants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    document text,
    status public.tenant_status DEFAULT 'trial'::public.tenant_status NOT NULL,
    plan_id uuid,
    timezone text DEFAULT 'America/Sao_Paulo'::text NOT NULL,
    trial_ends_at timestamp with time zone,
    stripe_customer_id text,
    stripe_subscription_id text,
    current_period_start timestamp with time zone,
    current_period_end timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: webhook_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider text DEFAULT 'meta'::text NOT NULL,
    external_event_id text NOT NULL,
    channel_external_id text,
    tenant_id uuid,
    payload jsonb NOT NULL,
    status text DEFAULT 'received'::text NOT NULL,
    error text,
    attempts integer DEFAULT 0 NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    processed_at timestamp with time zone
);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: channels channels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT channels_pkey PRIMARY KEY (id);


--
-- Name: channels channels_type_external_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT channels_type_external_unique UNIQUE (type, external_id);


--
-- Name: contacts contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_pkey PRIMARY KEY (id);


--
-- Name: contacts contacts_tenant_channel_external_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_tenant_channel_external_unique UNIQUE (tenant_id, channel_id, external_user_id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: plans plans_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans
    ADD CONSTRAINT plans_code_key UNIQUE (code);


--
-- Name: plans plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plans
    ADD CONSTRAINT plans_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: tenant_secrets tenant_secrets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_secrets
    ADD CONSTRAINT tenant_secrets_pkey PRIMARY KEY (tenant_id);


--
-- Name: tenant_settings tenant_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_settings
    ADD CONSTRAINT tenant_settings_pkey PRIMARY KEY (tenant_id);


--
-- Name: tenants tenants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_pkey PRIMARY KEY (id);


--
-- Name: tenants tenants_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_slug_key UNIQUE (slug);


--
-- Name: tenants tenants_stripe_customer_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_stripe_customer_id_key UNIQUE (stripe_customer_id);


--
-- Name: tenants tenants_stripe_subscription_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_stripe_subscription_id_key UNIQUE (stripe_subscription_id);


--
-- Name: webhook_events webhook_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_events
    ADD CONSTRAINT webhook_events_pkey PRIMARY KEY (id);


--
-- Name: webhook_events webhook_events_provider_event_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_events
    ADD CONSTRAINT webhook_events_provider_event_unique UNIQUE (provider, external_event_id);


--
-- Name: channels_tenant_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX channels_tenant_idx ON public.channels USING btree (tenant_id) WHERE (status = 'connected'::public.channel_status);


--
-- Name: contacts_tenant_last_msg_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contacts_tenant_last_msg_idx ON public.contacts USING btree (tenant_id, last_message_at DESC);


--
-- Name: conversations_one_open_per_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX conversations_one_open_per_contact ON public.conversations USING btree (contact_id) WHERE (status <> 'closed'::public.conversation_status);


--
-- Name: conversations_tenant_assigned_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversations_tenant_assigned_idx ON public.conversations USING btree (tenant_id, assigned_to, status);


--
-- Name: conversations_tenant_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversations_tenant_status_idx ON public.conversations USING btree (tenant_id, status, last_message_at DESC);


--
-- Name: index_channels_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_channels_on_tenant_id ON public.channels USING btree (tenant_id);


--
-- Name: index_channels_on_type_and_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_channels_on_type_and_external_id ON public.channels USING btree (type, external_id);


--
-- Name: index_profiles_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_profiles_on_email ON public.profiles USING btree (email);


--
-- Name: index_profiles_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_profiles_on_tenant_id ON public.profiles USING btree (tenant_id);


--
-- Name: index_tenant_secrets_on_tenant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tenant_secrets_on_tenant_id ON public.tenant_secrets USING btree (tenant_id);


--
-- Name: index_tenants_on_plan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tenants_on_plan_id ON public.tenants USING btree (plan_id);


--
-- Name: messages_conversation_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_conversation_idx ON public.messages USING btree (conversation_id, created_at DESC);


--
-- Name: messages_provider_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX messages_provider_unique ON public.messages USING btree (tenant_id, provider_message_id) WHERE (provider_message_id IS NOT NULL);


--
-- Name: messages_tenant_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_tenant_idx ON public.messages USING btree (tenant_id, created_at DESC);


--
-- Name: notifications_tenant_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_tenant_user_idx ON public.notifications USING btree (tenant_id, user_id, read_at);


--
-- Name: profiles_email_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX profiles_email_unique ON public.profiles USING btree (lower(email));


--
-- Name: tenants_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tenants_status_idx ON public.tenants USING btree (status);


--
-- Name: channels trg_channels_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_channels_updated_at BEFORE UPDATE ON public.channels FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contacts trg_contacts_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_contacts_updated_at BEFORE UPDATE ON public.contacts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: conversations trg_conversations_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_conversations_updated_at BEFORE UPDATE ON public.conversations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: profiles trg_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: tenants trg_tenants_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_tenants_updated_at BEFORE UPDATE ON public.tenants FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: channels channels_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT channels_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: contacts contacts_channel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES public.channels(id) ON DELETE CASCADE;


--
-- Name: contacts contacts_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_assigned_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: conversations conversations_channel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES public.channels(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contacts(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: messages messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: messages messages_reply_to_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_reply_to_id_fkey FOREIGN KEY (reply_to_id) REFERENCES public.messages(id) ON DELETE SET NULL;


--
-- Name: messages messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: messages messages_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tenant_secrets tenant_secrets_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_secrets
    ADD CONSTRAINT tenant_secrets_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tenant_settings tenant_settings_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenant_settings
    ADD CONSTRAINT tenant_settings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE CASCADE;


--
-- Name: tenants tenants_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tenants
    ADD CONSTRAINT tenants_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.plans(id);


--
-- Name: webhook_events webhook_events_tenant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_events
    ADD CONSTRAINT webhook_events_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260818214506'),
('20260818214505'),
('20260818214504'),
('20260818214503'),
('20260818214502'),
('20260818214501');

