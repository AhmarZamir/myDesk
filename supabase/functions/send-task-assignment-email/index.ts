import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function escapeHtml(value: unknown): string {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;')
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const resendApiKey = Deno.env.get('RESEND_API_KEY')
    const emailFrom = Deno.env.get('TASK_EMAIL_FROM') ?? 'myDesk <onboarding@resend.dev>'
    const appUrl = Deno.env.get('MYDESK_APP_URL') ?? ''
    const authorization = req.headers.get('Authorization')

    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      throw new Error('Supabase function environment is not configured.')
    }
    if (!resendApiKey) {
      throw new Error('RESEND_API_KEY is not configured.')
    }
    if (!authorization) {
      return Response.json({ error: 'Missing authorization.' }, { status: 401, headers: corsHeaders })
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    })
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })

    const { data: authData, error: authError } = await userClient.auth.getUser()
    if (authError || !authData.user) {
      return Response.json({ error: 'Invalid session.' }, { status: 401, headers: corsHeaders })
    }

    const body = await req.json().catch(() => ({}))
    const taskId = typeof body.task_id === 'string' ? body.task_id : ''
    if (!taskId) {
      return Response.json({ error: 'task_id is required.' }, { status: 400, headers: corsHeaders })
    }

    // Read through the signed-in client first so normal task RLS is still respected.
    const { data: task, error: taskError } = await userClient
      .from('tasks')
      .select('id, creator_id, assignee_id, desk_id, title, description, due_date, priority')
      .eq('id', taskId)
      .single()

    if (taskError || !task) {
      return Response.json({ error: 'Task not found or not accessible.' }, { status: 404, headers: corsHeaders })
    }
    if (task.creator_id !== authData.user.id) {
      return Response.json({ error: 'Only the task creator can send an assignment email.' }, { status: 403, headers: corsHeaders })
    }
    if (!task.assignee_id || task.assignee_id === authData.user.id) {
      return Response.json({ sent: false, reason: 'No external assignee.' }, { headers: corsHeaders })
    }

    const { data: assigneeData, error: assigneeError } = await admin.auth.admin.getUserById(task.assignee_id)
    const recipientEmail = assigneeData?.user?.email
    if (assigneeError || !recipientEmail) {
      return Response.json({ error: 'The assignee does not have a registered email address.' }, { status: 422, headers: corsHeaders })
    }

    const [{ data: creatorProfile }, { data: desk }] = await Promise.all([
      admin.from('profiles').select('full_name').eq('id', task.creator_id).maybeSingle(),
      task.desk_id
        ? admin.from('shared_desks').select('name').eq('id', task.desk_id).maybeSingle()
        : Promise.resolve({ data: null }),
    ])

    const assignerName = creatorProfile?.full_name?.trim() || authData.user.email || 'Someone'
    const workspaceName = desk?.name?.trim() || (task.desk_id ? 'Shared Desk' : 'Direct assignment')
    const dueText = task.due_date ? new Date(task.due_date).toLocaleDateString('en-PK') : 'No due date'
    const description = task.description?.trim() || 'No description provided.'
    const taskLink = appUrl ? `${appUrl.replace(/\/$/, '')}/?task=${encodeURIComponent(task.id)}` : ''

    const html = `
      <div style="font-family:Arial,sans-serif;max-width:620px;margin:0 auto;color:#111827">
        <div style="background:#0b1220;padding:24px;border-radius:16px 16px 0 0;color:white">
          <div style="font-size:13px;opacity:.75">myDesk</div>
          <h1 style="margin:8px 0 0;font-size:24px">You have a new task</h1>
        </div>
        <div style="border:1px solid #e5e7eb;border-top:0;padding:26px;border-radius:0 0 16px 16px">
          <p style="margin-top:0"><strong>${escapeHtml(assignerName)}</strong> assigned a task to you.</p>
          <h2 style="font-size:20px;margin-bottom:8px">${escapeHtml(task.title)}</h2>
          <p style="line-height:1.6;color:#4b5563">${escapeHtml(description)}</p>
          <table style="width:100%;border-collapse:collapse;margin:20px 0">
            <tr><td style="padding:7px 0;color:#6b7280">Priority</td><td style="padding:7px 0;font-weight:700">${escapeHtml(task.priority)}</td></tr>
            <tr><td style="padding:7px 0;color:#6b7280">Due</td><td style="padding:7px 0;font-weight:700">${escapeHtml(dueText)}</td></tr>
            <tr><td style="padding:7px 0;color:#6b7280">Workspace</td><td style="padding:7px 0;font-weight:700">${escapeHtml(workspaceName)}</td></tr>
          </table>
          ${taskLink ? `<a href="${escapeHtml(taskLink)}" style="display:inline-block;background:#2f80ff;color:white;text-decoration:none;font-weight:700;padding:12px 18px;border-radius:10px">Open myDesk</a>` : ''}
          <p style="margin:24px 0 0;font-size:12px;color:#9ca3af">This email was sent because a myDesk user assigned a task to your account.</p>
        </div>
      </div>`

    const resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: emailFrom,
        to: [recipientEmail],
        subject: `New task: ${task.title}`,
        html,
      }),
    })

    const resendData = await resendResponse.json().catch(() => ({}))
    if (!resendResponse.ok) {
      console.error('Resend task email failed', resendData)
      return Response.json({ error: 'Email provider rejected the message.' }, { status: 502, headers: corsHeaders })
    }

    return Response.json({ sent: true, id: resendData.id }, { headers: corsHeaders })
  } catch (error) {
    console.error('send-task-assignment-email failed', error)
    return Response.json({ error: error instanceof Error ? error.message : 'Unexpected error.' }, { status: 500, headers: corsHeaders })
  }
})
