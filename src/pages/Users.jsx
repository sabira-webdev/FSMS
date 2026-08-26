import React from 'react'
import { UserCog, Plus, Search, Shield, Key } from 'lucide-react'
import {
  PageHeader,
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
  Badge,
  Button,
  Input,
} from '../components/common'

export function Users() {
  return (
    <div className="space-y-6">
      <PageHeader
        title="Users & Permissions"
        subtitle="Manage administrative accounts, role-based access control (RBAC), and security privileges."
        badge={<Badge variant="neutral" size="sm">Admin Only</Badge>}
        breadcrumbs={[{ label: 'Home', path: '/' }, { label: 'Users' }]}
        actions={
          <Button variant="primary" size="sm" icon={Plus}>
            Invite User
          </Button>
        }
      />

      <Card>
        <CardHeader className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <CardTitle>System Accounts & Access Rights</CardTitle>
            <CardDescription>Assign roles: Super Admin, Quality Manager, Lead Auditor, Shift Inspector.</CardDescription>
          </div>
          <Input
            icon={Search}
            placeholder="Search users..."
            className="w-full sm:w-64"
          />
        </CardHeader>
        <CardContent>
          <div className="py-12 flex flex-col items-center justify-center text-center max-w-md mx-auto space-y-3">
            <div className="w-12 h-12 rounded-2xl bg-emerald-50 text-emerald-600 flex items-center justify-center border border-emerald-100">
              <UserCog className="w-6 h-6" />
            </div>
            <h4 className="text-base font-bold text-slate-800">User Management Ready</h4>
            <p className="text-xs text-slate-500 leading-relaxed">
              Foundation established. Supabase Authentication and role-based policies will be hooked up in the authentication phase.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
