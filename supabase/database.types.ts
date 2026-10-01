export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      claims: {
        Row: {
          billing_type: Database["public"]["Enums"]["billing_type"] | null
          cancelled: boolean
          cause: string | null
          cause_detail: string | null
          coverage_recommendation: string | null
          project_id: string
          property_type: string | null
          water_category: number | null
        }
        Insert: {
          billing_type?: Database["public"]["Enums"]["billing_type"] | null
          cancelled?: boolean
          cause?: string | null
          cause_detail?: string | null
          coverage_recommendation?: string | null
          project_id: string
          property_type?: string | null
          water_category?: number | null
        }
        Update: {
          billing_type?: Database["public"]["Enums"]["billing_type"] | null
          cancelled?: boolean
          cause?: string | null
          cause_detail?: string | null
          coverage_recommendation?: string | null
          project_id?: string
          property_type?: string | null
          water_category?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "claims_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: true
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      contract_templates: {
        Row: {
          body: string
          id: string
          name: string
          workspace_id: string
        }
        Insert: {
          body: string
          id?: string
          name: string
          workspace_id: string
        }
        Update: {
          body?: string
          id?: string
          name?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "contract_templates_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      customers: {
        Row: {
          created_at: string
          email: string | null
          full_name: string
          id: string
          phone: string | null
          property_type: string | null
          updated_at: string
          workspace_id: string
        }
        Insert: {
          created_at?: string
          email?: string | null
          full_name: string
          id?: string
          phone?: string | null
          property_type?: string | null
          updated_at?: string
          workspace_id: string
        }
        Update: {
          created_at?: string
          email?: string | null
          full_name?: string
          id?: string
          phone?: string | null
          property_type?: string | null
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "customers_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      drying_plans: {
        Row: {
          plan: Json
          project_id: string
          updated_at: string
        }
        Insert: {
          plan?: Json
          project_id: string
          updated_at?: string
        }
        Update: {
          plan?: Json
          project_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "drying_plans_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: true
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      member_availability: {
        Row: {
          available_9_5: boolean
          available_after_hours: boolean
          day_of_week: number
          user_id: string
          workspace_id: string
        }
        Insert: {
          available_9_5?: boolean
          available_after_hours?: boolean
          day_of_week: number
          user_id: string
          workspace_id: string
        }
        Update: {
          available_9_5?: boolean
          available_after_hours?: boolean
          day_of_week?: number
          user_id?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "member_availability_workspace_id_user_id_fkey"
            columns: ["workspace_id", "user_id"]
            isOneToOne: false
            referencedRelation: "workspace_members"
            referencedColumns: ["workspace_id", "user_id"]
          },
        ]
      }
      member_services: {
        Row: {
          created_at: string
          service_id: string
          tier: number
          user_id: string
          verification_status: Database["public"]["Enums"]["verification_status"]
          workspace_id: string
        }
        Insert: {
          created_at?: string
          service_id: string
          tier?: number
          user_id: string
          verification_status?: Database["public"]["Enums"]["verification_status"]
          workspace_id: string
        }
        Update: {
          created_at?: string
          service_id?: string
          tier?: number
          user_id?: string
          verification_status?: Database["public"]["Enums"]["verification_status"]
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "member_services_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "services"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "member_services_workspace_id_user_id_fkey"
            columns: ["workspace_id", "user_id"]
            isOneToOne: false
            referencedRelation: "workspace_members"
            referencedColumns: ["workspace_id", "user_id"]
          },
        ]
      }
      moisture_readings: {
        Row: {
          dry_standard: number | null
          ep_goal: number | null
          floor_id: string
          id: string
          material: string | null
          name: string
          recorded_at: string
          room_id: string | null
          wetness: string
          x: number | null
          y: number | null
        }
        Insert: {
          dry_standard?: number | null
          ep_goal?: number | null
          floor_id: string
          id?: string
          material?: string | null
          name: string
          recorded_at?: string
          room_id?: string | null
          wetness: string
          x?: number | null
          y?: number | null
        }
        Update: {
          dry_standard?: number | null
          ep_goal?: number | null
          floor_id?: string
          id?: string
          material?: string | null
          name?: string
          recorded_at?: string
          room_id?: string | null
          wetness?: string
          x?: number | null
          y?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "moisture_readings_floor_id_fkey"
            columns: ["floor_id"]
            isOneToOne: false
            referencedRelation: "project_floors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "moisture_readings_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "project_rooms"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          body: string | null
          created_at: string
          id: string
          opportunity_id: string | null
          project_id: string | null
          read_at: string | null
          title: string
          user_id: string
          workspace_id: string | null
        }
        Insert: {
          body?: string | null
          created_at?: string
          id?: string
          opportunity_id?: string | null
          project_id?: string | null
          read_at?: string | null
          title: string
          user_id: string
          workspace_id?: string | null
        }
        Update: {
          body?: string | null
          created_at?: string
          id?: string
          opportunity_id?: string | null
          project_id?: string | null
          read_at?: string | null
          title?: string
          user_id?: string
          workspace_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "notifications_opportunity_id_fkey"
            columns: ["opportunity_id"]
            isOneToOne: false
            referencedRelation: "opportunities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      opportunities: {
        Row: {
          accepted_at: string | null
          accepted_by: string | null
          accepted_workspace_id: string | null
          address: string | null
          cause: string | null
          city: string | null
          created_at: string
          created_by: string | null
          customer_id: string
          damage_notes: string | null
          id: string
          latitude: number | null
          longitude: number | null
          notify_before_hours: number
          postal_code: string
          preferred_date: string | null
          preferred_window: string | null
          priority: Database["public"]["Enums"]["dispatch_priority"]
          service_id: string
          source: Database["public"]["Enums"]["opportunity_source"]
          state: string | null
          status: Database["public"]["Enums"]["opportunity_status"]
          updated_at: string
          visibility: Database["public"]["Enums"]["opportunity_visibility"]
          workspace_id: string
        }
        Insert: {
          accepted_at?: string | null
          accepted_by?: string | null
          accepted_workspace_id?: string | null
          address?: string | null
          cause?: string | null
          city?: string | null
          created_at?: string
          created_by?: string | null
          customer_id: string
          damage_notes?: string | null
          id?: string
          latitude?: number | null
          longitude?: number | null
          notify_before_hours?: number
          postal_code: string
          preferred_date?: string | null
          preferred_window?: string | null
          priority?: Database["public"]["Enums"]["dispatch_priority"]
          service_id: string
          source: Database["public"]["Enums"]["opportunity_source"]
          state?: string | null
          status?: Database["public"]["Enums"]["opportunity_status"]
          updated_at?: string
          visibility?: Database["public"]["Enums"]["opportunity_visibility"]
          workspace_id: string
        }
        Update: {
          accepted_at?: string | null
          accepted_by?: string | null
          accepted_workspace_id?: string | null
          address?: string | null
          cause?: string | null
          city?: string | null
          created_at?: string
          created_by?: string | null
          customer_id?: string
          damage_notes?: string | null
          id?: string
          latitude?: number | null
          longitude?: number | null
          notify_before_hours?: number
          postal_code?: string
          preferred_date?: string | null
          preferred_window?: string | null
          priority?: Database["public"]["Enums"]["dispatch_priority"]
          service_id?: string
          source?: Database["public"]["Enums"]["opportunity_source"]
          state?: string | null
          status?: Database["public"]["Enums"]["opportunity_status"]
          updated_at?: string
          visibility?: Database["public"]["Enums"]["opportunity_visibility"]
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "opportunities_accepted_by_fkey"
            columns: ["accepted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "opportunities_accepted_workspace_id_fkey"
            columns: ["accepted_workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "opportunities_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "opportunities_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "opportunities_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "services"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "opportunities_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      opportunity_media: {
        Row: {
          created_at: string
          file_name: string | null
          id: string
          mime_type: string
          opportunity_id: string
          size_bytes: number
          storage_path: string
        }
        Insert: {
          created_at?: string
          file_name?: string | null
          id?: string
          mime_type: string
          opportunity_id: string
          size_bytes: number
          storage_path: string
        }
        Update: {
          created_at?: string
          file_name?: string | null
          id?: string
          mime_type?: string
          opportunity_id?: string
          size_bytes?: number
          storage_path?: string
        }
        Relationships: [
          {
            foreignKeyName: "opportunity_media_opportunity_id_fkey"
            columns: ["opportunity_id"]
            isOneToOne: false
            referencedRelation: "opportunities"
            referencedColumns: ["id"]
          },
        ]
      }
      opportunity_offers: {
        Row: {
          expires_at: string
          id: string
          offered_at: string
          opportunity_id: string
          responded_at: string | null
          status: Database["public"]["Enums"]["offer_status"]
          tier: number
          user_id: string
          workspace_id: string
        }
        Insert: {
          expires_at: string
          id?: string
          offered_at?: string
          opportunity_id: string
          responded_at?: string | null
          status?: Database["public"]["Enums"]["offer_status"]
          tier: number
          user_id: string
          workspace_id: string
        }
        Update: {
          expires_at?: string
          id?: string
          offered_at?: string
          opportunity_id?: string
          responded_at?: string | null
          status?: Database["public"]["Enums"]["offer_status"]
          tier?: number
          user_id?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "opportunity_offers_opportunity_id_fkey"
            columns: ["opportunity_id"]
            isOneToOne: false
            referencedRelation: "opportunities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "opportunity_offers_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "opportunity_offers_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      payments: {
        Row: {
          amount: number
          created_at: string
          id: string
          kind: string
          paid_at: string | null
          project_id: string
          status: string
          stripe_payment_id: string | null
        }
        Insert: {
          amount: number
          created_at?: string
          id?: string
          kind: string
          paid_at?: string | null
          project_id: string
          status?: string
          stripe_payment_id?: string | null
        }
        Update: {
          amount?: number
          created_at?: string
          id?: string
          kind?: string
          paid_at?: string | null
          project_id?: string
          status?: string
          stripe_payment_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "payments_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          email: string | null
          full_name: string | null
          id: string
          is_platform_admin: boolean
          phone: string | null
          stripe_account_id: string | null
          updated_at: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          email?: string | null
          full_name?: string | null
          id: string
          is_platform_admin?: boolean
          phone?: string | null
          stripe_account_id?: string | null
          updated_at?: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          email?: string | null
          full_name?: string | null
          id?: string
          is_platform_admin?: boolean
          phone?: string | null
          stripe_account_id?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      project_activity: {
        Row: {
          action: string
          actor_id: string | null
          created_at: string
          details: Json
          id: string
          project_id: string
        }
        Insert: {
          action: string
          actor_id?: string | null
          created_at?: string
          details?: Json
          id?: string
          project_id: string
        }
        Update: {
          action?: string
          actor_id?: string | null
          created_at?: string
          details?: Json
          id?: string
          project_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_activity_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_activity_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      project_contracts: {
        Row: {
          id: string
          project_id: string
          signature_url: string | null
          signed_at: string | null
          signed_by: string | null
          signed_in_person: boolean
          template_id: string
        }
        Insert: {
          id?: string
          project_id: string
          signature_url?: string | null
          signed_at?: string | null
          signed_by?: string | null
          signed_in_person?: boolean
          template_id: string
        }
        Update: {
          id?: string
          project_id?: string
          signature_url?: string | null
          signed_at?: string | null
          signed_by?: string | null
          signed_in_person?: boolean
          template_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_contracts_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_contracts_template_id_fkey"
            columns: ["template_id"]
            isOneToOne: false
            referencedRelation: "contract_templates"
            referencedColumns: ["id"]
          },
        ]
      }
      project_emails: {
        Row: {
          body: string | null
          direction: string
          id: string
          project_id: string
          sent_at: string | null
          subject: string | null
        }
        Insert: {
          body?: string | null
          direction: string
          id?: string
          project_id: string
          sent_at?: string | null
          subject?: string | null
        }
        Update: {
          body?: string | null
          direction?: string
          id?: string
          project_id?: string
          sent_at?: string | null
          subject?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "project_emails_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      project_expenses: {
        Row: {
          amount: number
          description: string
          id: string
          incurred_at: string
          incurred_by: string | null
          project_id: string
        }
        Insert: {
          amount: number
          description: string
          id?: string
          incurred_at?: string
          incurred_by?: string | null
          project_id: string
        }
        Update: {
          amount?: number
          description?: string
          id?: string
          incurred_at?: string
          incurred_by?: string | null
          project_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_expenses_incurred_by_fkey"
            columns: ["incurred_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_expenses_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      project_files: {
        Row: {
          created_at: string
          id: string
          kind: string
          project_id: string
          storage_path: string
          uploaded_by: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          kind: string
          project_id: string
          storage_path: string
          uploaded_by?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          kind?: string
          project_id?: string
          storage_path?: string
          uploaded_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "project_files_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_files_uploaded_by_fkey"
            columns: ["uploaded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      project_floors: {
        Row: {
          id: string
          name: string
          position: number
          project_id: string
          sketch: Json
        }
        Insert: {
          id?: string
          name: string
          position?: number
          project_id: string
          sketch?: Json
        }
        Update: {
          id?: string
          name?: string
          position?: number
          project_id?: string
          sketch?: Json
        }
        Relationships: [
          {
            foreignKeyName: "project_floors_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      project_members: {
        Row: {
          added_by: string | null
          created_at: string
          project_id: string
          role: Database["public"]["Enums"]["participant_role"]
          user_id: string
        }
        Insert: {
          added_by?: string | null
          created_at?: string
          project_id: string
          role: Database["public"]["Enums"]["participant_role"]
          user_id: string
        }
        Update: {
          added_by?: string | null
          created_at?: string
          project_id?: string
          role?: Database["public"]["Enums"]["participant_role"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_members_added_by_fkey"
            columns: ["added_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_members_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      project_rooms: {
        Row: {
          floor_id: string
          id: string
          name: string
        }
        Insert: {
          floor_id: string
          id?: string
          name: string
        }
        Update: {
          floor_id?: string
          id?: string
          name?: string
        }
        Relationships: [
          {
            foreignKeyName: "project_rooms_floor_id_fkey"
            columns: ["floor_id"]
            isOneToOne: false
            referencedRelation: "project_floors"
            referencedColumns: ["id"]
          },
        ]
      }
      project_scope_items: {
        Row: {
          description: string
          id: string
          package_id: string | null
          project_id: string
          quantity: number
          unit_price: number
        }
        Insert: {
          description: string
          id?: string
          package_id?: string | null
          project_id: string
          quantity: number
          unit_price: number
        }
        Update: {
          description?: string
          id?: string
          package_id?: string | null
          project_id?: string
          quantity?: number
          unit_price?: number
        }
        Relationships: [
          {
            foreignKeyName: "project_scope_items_package_id_fkey"
            columns: ["package_id"]
            isOneToOne: false
            referencedRelation: "service_packages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_scope_items_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      project_steps: {
        Row: {
          completed_at: string | null
          data: Json
          project_id: string
          step: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          completed_at?: string | null
          data?: Json
          project_id: string
          step: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          completed_at?: string | null
          data?: Json
          project_id?: string
          step?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "project_steps_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "project_steps_step_fkey"
            columns: ["step"]
            isOneToOne: false
            referencedRelation: "workflow_steps"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "project_steps_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      projects: {
        Row: {
          assigned_to: string | null
          billing_type: Database["public"]["Enums"]["billing_type"] | null
          completed_at: string | null
          created_at: string
          current_step: string
          customer_id: string
          id: string
          opportunity_id: string
          payment_status: Database["public"]["Enums"]["payment_status"]
          scheduled_start: string | null
          scope_estimate: number | null
          service_id: string
          status: Database["public"]["Enums"]["project_status"]
          updated_at: string
          workspace_id: string
        }
        Insert: {
          assigned_to?: string | null
          billing_type?: Database["public"]["Enums"]["billing_type"] | null
          completed_at?: string | null
          created_at?: string
          current_step?: string
          customer_id: string
          id?: string
          opportunity_id: string
          payment_status?: Database["public"]["Enums"]["payment_status"]
          scheduled_start?: string | null
          scope_estimate?: number | null
          service_id: string
          status?: Database["public"]["Enums"]["project_status"]
          updated_at?: string
          workspace_id: string
        }
        Update: {
          assigned_to?: string | null
          billing_type?: Database["public"]["Enums"]["billing_type"] | null
          completed_at?: string | null
          created_at?: string
          current_step?: string
          customer_id?: string
          id?: string
          opportunity_id?: string
          payment_status?: Database["public"]["Enums"]["payment_status"]
          scheduled_start?: string | null
          scope_estimate?: number | null
          service_id?: string
          status?: Database["public"]["Enums"]["project_status"]
          updated_at?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "projects_assigned_to_fkey"
            columns: ["assigned_to"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "projects_current_step_fkey"
            columns: ["current_step"]
            isOneToOne: false
            referencedRelation: "workflow_steps"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "projects_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "projects_opportunity_id_fkey"
            columns: ["opportunity_id"]
            isOneToOne: true
            referencedRelation: "opportunities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "projects_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "services"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "projects_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      referral_invites: {
        Row: {
          claimed_at: string | null
          claimed_by: string | null
          created_at: string
          expires_at: string
          id: string
          invited_by: string
          invitee_email: string | null
          invitee_name: string
          invitee_phone: string | null
          invitee_workspace_id: string | null
          payout_amount: number
          project_id: string
          special_instructions: string | null
          status: Database["public"]["Enums"]["referral_status"]
          target: Database["public"]["Enums"]["referral_target"]
          token: string
          updated_at: string
          viewed_at: string | null
          workspace_id: string
        }
        Insert: {
          claimed_at?: string | null
          claimed_by?: string | null
          created_at?: string
          expires_at?: string
          id?: string
          invited_by: string
          invitee_email?: string | null
          invitee_name: string
          invitee_phone?: string | null
          invitee_workspace_id?: string | null
          payout_amount?: number
          project_id: string
          special_instructions?: string | null
          status?: Database["public"]["Enums"]["referral_status"]
          target?: Database["public"]["Enums"]["referral_target"]
          token?: string
          updated_at?: string
          viewed_at?: string | null
          workspace_id: string
        }
        Update: {
          claimed_at?: string | null
          claimed_by?: string | null
          created_at?: string
          expires_at?: string
          id?: string
          invited_by?: string
          invitee_email?: string | null
          invitee_name?: string
          invitee_phone?: string | null
          invitee_workspace_id?: string | null
          payout_amount?: number
          project_id?: string
          special_instructions?: string | null
          status?: Database["public"]["Enums"]["referral_status"]
          target?: Database["public"]["Enums"]["referral_target"]
          token?: string
          updated_at?: string
          viewed_at?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "referral_invites_claimed_by_fkey"
            columns: ["claimed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_invites_invited_by_fkey"
            columns: ["invited_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_invites_invitee_workspace_id_fkey"
            columns: ["invitee_workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_invites_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_invites_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      referral_payouts: {
        Row: {
          amount: number
          created_at: string
          id: string
          invite_id: string
          payee_id: string
          project_id: string
          released_at: string | null
          status: Database["public"]["Enums"]["payout_status"]
          stripe_transfer_id: string | null
          updated_at: string
        }
        Insert: {
          amount: number
          created_at?: string
          id?: string
          invite_id: string
          payee_id: string
          project_id: string
          released_at?: string | null
          status?: Database["public"]["Enums"]["payout_status"]
          stripe_transfer_id?: string | null
          updated_at?: string
        }
        Update: {
          amount?: number
          created_at?: string
          id?: string
          invite_id?: string
          payee_id?: string
          project_id?: string
          released_at?: string | null
          status?: Database["public"]["Enums"]["payout_status"]
          stripe_transfer_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "referral_payouts_invite_id_fkey"
            columns: ["invite_id"]
            isOneToOne: true
            referencedRelation: "referral_invites"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_payouts_payee_id_fkey"
            columns: ["payee_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_payouts_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      room_materials: {
        Row: {
          affected: boolean
          id: string
          material: string
          room_id: string
          surface: string
        }
        Insert: {
          affected?: boolean
          id?: string
          material: string
          room_id: string
          surface: string
        }
        Update: {
          affected?: boolean
          id?: string
          material?: string
          room_id?: string
          surface?: string
        }
        Relationships: [
          {
            foreignKeyName: "room_materials_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "project_rooms"
            referencedColumns: ["id"]
          },
        ]
      }
      room_measurements: {
        Row: {
          affected: boolean
          affected_sqft: number | null
          height_in: number | null
          length_in: number | null
          room_id: string
          total_sqft: number | null
          width_in: number | null
        }
        Insert: {
          affected?: boolean
          affected_sqft?: number | null
          height_in?: number | null
          length_in?: number | null
          room_id: string
          total_sqft?: number | null
          width_in?: number | null
        }
        Update: {
          affected?: boolean
          affected_sqft?: number | null
          height_in?: number | null
          length_in?: number | null
          room_id?: string
          total_sqft?: number | null
          width_in?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "room_measurements_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: true
            referencedRelation: "project_rooms"
            referencedColumns: ["id"]
          },
        ]
      }
      room_photos: {
        Row: {
          id: string
          is_additional: boolean
          position: number
          room_id: string
          storage_path: string
        }
        Insert: {
          id?: string
          is_additional?: boolean
          position?: number
          room_id: string
          storage_path: string
        }
        Update: {
          id?: string
          is_additional?: boolean
          position?: number
          room_id?: string
          storage_path?: string
        }
        Relationships: [
          {
            foreignKeyName: "room_photos_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "project_rooms"
            referencedColumns: ["id"]
          },
        ]
      }
      service_packages: {
        Row: {
          description: string | null
          id: string
          image_url: string | null
          name: string
          price: number
          service_id: string | null
          workspace_id: string
        }
        Insert: {
          description?: string | null
          id?: string
          image_url?: string | null
          name: string
          price: number
          service_id?: string | null
          workspace_id: string
        }
        Update: {
          description?: string | null
          id?: string
          image_url?: string | null
          name?: string
          price?: number
          service_id?: string | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "service_packages_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "services"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_packages_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      services: {
        Row: {
          code: string
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          is_bookable: boolean
          name: string
          requires_verification: boolean
          response_label: string | null
          sort_order: number
          tag: string | null
        }
        Insert: {
          code: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          is_bookable?: boolean
          name: string
          requires_verification?: boolean
          response_label?: string | null
          sort_order?: number
          tag?: string | null
        }
        Update: {
          code?: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          is_bookable?: boolean
          name?: string
          requires_verification?: boolean
          response_label?: string | null
          sort_order?: number
          tag?: string | null
        }
        Relationships: []
      }
      workflow_steps: {
        Row: {
          code: string
          name: string
          position: number
        }
        Insert: {
          code: string
          name: string
          position: number
        }
        Update: {
          code?: string
          name?: string
          position?: number
        }
        Relationships: []
      }
      workspace_locations: {
        Row: {
          created_at: string
          id: string
          latitude: number | null
          longitude: number | null
          name: string
          postal_codes: string[]
          service_radius_miles: number | null
          workspace_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          latitude?: number | null
          longitude?: number | null
          name: string
          postal_codes?: string[]
          service_radius_miles?: number | null
          workspace_id: string
        }
        Update: {
          created_at?: string
          id?: string
          latitude?: number | null
          longitude?: number | null
          name?: string
          postal_codes?: string[]
          service_radius_miles?: number | null
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "workspace_locations_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      workspace_members: {
        Row: {
          allowed_to_schedule: boolean
          available_for_scheduling: boolean
          commission_pct: number | null
          created_at: string
          job_title: string | null
          member_type: Database["public"]["Enums"]["member_type"]
          referred_by: string | null
          role: Database["public"]["Enums"]["workspace_role"]
          status: Database["public"]["Enums"]["member_status"]
          updated_at: string
          user_id: string
          workspace_id: string
        }
        Insert: {
          allowed_to_schedule?: boolean
          available_for_scheduling?: boolean
          commission_pct?: number | null
          created_at?: string
          job_title?: string | null
          member_type?: Database["public"]["Enums"]["member_type"]
          referred_by?: string | null
          role?: Database["public"]["Enums"]["workspace_role"]
          status?: Database["public"]["Enums"]["member_status"]
          updated_at?: string
          user_id: string
          workspace_id: string
        }
        Update: {
          allowed_to_schedule?: boolean
          available_for_scheduling?: boolean
          commission_pct?: number | null
          created_at?: string
          job_title?: string | null
          member_type?: Database["public"]["Enums"]["member_type"]
          referred_by?: string | null
          role?: Database["public"]["Enums"]["workspace_role"]
          status?: Database["public"]["Enums"]["member_status"]
          updated_at?: string
          user_id?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "workspace_members_referred_by_fkey"
            columns: ["referred_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "workspace_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "workspace_members_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      workspace_services: {
        Row: {
          service_id: string
          workspace_id: string
        }
        Insert: {
          service_id: string
          workspace_id: string
        }
        Update: {
          service_id?: string
          workspace_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "workspace_services_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "services"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "workspace_services_workspace_id_fkey"
            columns: ["workspace_id"]
            isOneToOne: false
            referencedRelation: "workspaces"
            referencedColumns: ["id"]
          },
        ]
      }
      workspaces: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          is_active: boolean
          logo_url: string | null
          name: string
          public_key: string
          slug: string
          tier_timeout_minutes: number
          timezone: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          logo_url?: string | null
          name: string
          public_key?: string
          slug: string
          tier_timeout_minutes?: number
          timezone?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          logo_url?: string | null
          name?: string
          public_key?: string
          slug?: string
          tier_timeout_minutes?: number
          timezone?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "workspaces_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      accept_opportunity: {
        Args: { p_opportunity: string; p_workspace?: string }
        Returns: string
      }
      accept_referral_listing: {
        Args: { p_invite: string; p_workspace?: string }
        Returns: string
      }
      add_workspace_member: {
        Args: {
          p_email: string
          p_job_title?: string
          p_role?: Database["public"]["Enums"]["workspace_role"]
          p_workspace: string
        }
        Returns: string
      }
      assign_project: {
        Args: { p_project: string; p_user: string }
        Returns: undefined
      }
      attach_media: {
        Args: {
          p_file_name: string
          p_mime: string
          p_opportunity: string
          p_path: string
          p_size: number
          p_token: string
        }
        Returns: string
      }
      claim_referral: {
        Args: { p_token: string; p_workspace?: string }
        Returns: string
      }
      create_project_upload_token: {
        Args: { p_project: string }
        Returns: Json
      }
      create_referral: {
        Args: {
          p_email?: string
          p_instructions?: string
          p_name: string
          p_payout?: number
          p_phone?: string
          p_project: string
          p_send?: boolean
          p_target: Database["public"]["Enums"]["referral_target"]
          p_workspace?: string
        }
        Returns: Json
      }
      create_workspace: {
        Args: {
          p_admin_email?: string
          p_name: string
          p_service_ids?: string[]
          p_slug: string
          p_timezone?: string
        }
        Returns: Json
      }
      dashboard_stats: { Args: { p_workspace?: string }; Returns: Json }
      decline_offer: { Args: { p_offer: string }; Returns: undefined }
      get_booking_form: { Args: { p_public_key: string }; Returns: Json }
      list_referral_contacts: { Args: { p_workspace: string }; Returns: Json }
      mark_notifications_read: { Args: { p_ids?: string[] }; Returns: number }
      preview_referral: { Args: { p_token: string }; Returns: Json }
      refer_opportunity: {
        Args: {
          p_email?: string
          p_instructions?: string
          p_name?: string
          p_opportunity: string
          p_payout?: number
          p_phone?: string
          p_target: Database["public"]["Enums"]["referral_target"]
          p_target_workspace?: string
          p_workspace: string
        }
        Returns: Json
      }
      referral_board: { Args: never; Returns: Json }
      revoke_referral: { Args: { p_invite: string }; Returns: undefined }
      save_customer: {
        Args: {
          p_email?: string
          p_id?: string
          p_name: string
          p_phone?: string
          p_property_type?: string
          p_workspace: string
        }
        Returns: {
          created_at: string
          email: string | null
          full_name: string
          id: string
          phone: string | null
          property_type: string | null
          updated_at: string
          workspace_id: string
        }
        SetofOptions: {
          from: "*"
          to: "customers"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      save_project_step: {
        Args: {
          p_complete?: boolean
          p_data?: Json
          p_project: string
          p_step: string
        }
        Returns: {
          completed_at: string | null
          data: Json
          project_id: string
          step: string
          updated_at: string
          updated_by: string | null
        }
        SetofOptions: {
          from: "*"
          to: "project_steps"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      save_workspace_services: {
        Args: { p_services: string[]; p_workspace: string }
        Returns: undefined
      }
      set_member_services: {
        Args: { p_items: Json; p_user: string; p_workspace: string }
        Returns: undefined
      }
      set_project_status: {
        Args: {
          p_project: string
          p_status: Database["public"]["Enums"]["project_status"]
        }
        Returns: undefined
      }
      submit_booking: {
        Args: {
          p_address?: string
          p_city?: string
          p_damage_notes?: string
          p_email: string
          p_full_name: string
          p_latitude?: number
          p_longitude?: number
          p_notify_before_hours?: number
          p_phone: string
          p_postal_code: string
          p_preferred_date?: string
          p_preferred_window?: string
          p_priority?: Database["public"]["Enums"]["dispatch_priority"]
          p_public_key: string
          p_service_code: string
          p_state?: string
          p_visibility?: Database["public"]["Enums"]["opportunity_visibility"]
        }
        Returns: Json
      }
      update_member_settings: {
        Args: {
          p_role?: Database["public"]["Enums"]["workspace_role"]
          p_scheduling?: boolean
          p_status?: Database["public"]["Enums"]["member_status"]
          p_user: string
          p_workspace: string
        }
        Returns: undefined
      }
      update_project_details: {
        Args: {
          p_billing?: Database["public"]["Enums"]["billing_type"]
          p_payment?: Database["public"]["Enums"]["payment_status"]
          p_project: string
          p_scope?: number
        }
        Returns: {
          assigned_to: string | null
          billing_type: Database["public"]["Enums"]["billing_type"] | null
          completed_at: string | null
          created_at: string
          current_step: string
          customer_id: string
          id: string
          opportunity_id: string
          payment_status: Database["public"]["Enums"]["payment_status"]
          scheduled_start: string | null
          scope_estimate: number | null
          service_id: string
          status: Database["public"]["Enums"]["project_status"]
          updated_at: string
          workspace_id: string
        }
        SetofOptions: {
          from: "*"
          to: "projects"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      workspace_directory: { Args: never; Returns: Json }
    }
    Enums: {
      billing_type: "insurance" | "self_pay" | "direct_commercial" | "hold"
      dispatch_priority: "emergency" | "scheduled"
      member_status: "invited" | "active" | "disabled"
      member_type: "internal" | "referral"
      offer_status:
        | "pending"
        | "accepted"
        | "declined"
        | "expired"
        | "withdrawn"
      opportunity_source: "public_form" | "internal_form" | "referral"
      opportunity_status:
        | "new"
        | "offered"
        | "accepted"
        | "cancelled"
        | "expired"
      opportunity_visibility: "public" | "private"
      participant_role: "assignee" | "crew" | "referral"
      payment_status: "pending" | "partial" | "paid"
      payout_status: "pending" | "held" | "released" | "paid" | "cancelled"
      project_status:
        | "accepted"
        | "en_route"
        | "in_progress"
        | "inspection"
        | "completed"
        | "cancelled"
      referral_status:
        | "draft"
        | "link_sent"
        | "viewed"
        | "accepted"
        | "in_progress"
        | "finished"
        | "revoked"
        | "expired"
      referral_target: "individual" | "workspace" | "opportunities"
      verification_status: "unverified" | "pending" | "verified" | "rejected"
      workspace_role: "admin" | "member"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      billing_type: ["insurance", "self_pay", "direct_commercial", "hold"],
      dispatch_priority: ["emergency", "scheduled"],
      member_status: ["invited", "active", "disabled"],
      member_type: ["internal", "referral"],
      offer_status: ["pending", "accepted", "declined", "expired", "withdrawn"],
      opportunity_source: ["public_form", "internal_form", "referral"],
      opportunity_status: [
        "new",
        "offered",
        "accepted",
        "cancelled",
        "expired",
      ],
      opportunity_visibility: ["public", "private"],
      participant_role: ["assignee", "crew", "referral"],
      payment_status: ["pending", "partial", "paid"],
      payout_status: ["pending", "held", "released", "paid", "cancelled"],
      project_status: [
        "accepted",
        "en_route",
        "in_progress",
        "inspection",
        "completed",
        "cancelled",
      ],
      referral_status: [
        "draft",
        "link_sent",
        "viewed",
        "accepted",
        "in_progress",
        "finished",
        "revoked",
        "expired",
      ],
      referral_target: ["individual", "workspace", "opportunities"],
      verification_status: ["unverified", "pending", "verified", "rejected"],
      workspace_role: ["admin", "member"],
    },
  },
} as const

