import React from 'react'
import { Routes, Route } from 'react-router-dom'
import { Layout } from '../components/layout/Layout'
import { Dashboard } from '../pages/Dashboard'
import { Employees } from '../pages/Employees'
import { AddEmployee } from '../pages/AddEmployee'
import { EditEmployee } from '../pages/EditEmployee'
import { EmployeeProfile } from '../pages/EmployeeProfile'
import { Departments } from '../pages/Departments'
import { Checklists } from '../pages/Checklists'
import { Inspections } from '../pages/Inspections'
import { Capa } from '../pages/Capa'
import { Reports } from '../pages/Reports'
import { Users } from '../pages/Users'
import { Settings } from '../pages/Settings'
import { Profile } from '../pages/Profile'
import { NotFound } from '../pages/NotFound'

/**
 * Main Application Routing Component
 */
export function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<Layout />}>
        <Route index element={<Dashboard />} />
        <Route path="employees" element={<Employees />} />
        <Route path="employees/new" element={<AddEmployee />} />
        <Route path="employees/:employeeId" element={<EmployeeProfile />} />
        <Route path="employees/:employeeId/edit" element={<EditEmployee />} />
        <Route path="departments" element={<Departments />} />
        <Route path="checklists" element={<Checklists />} />
        <Route path="inspections" element={<Inspections />} />
        <Route path="capa" element={<Capa />} />
        <Route path="reports" element={<Reports />} />
        <Route path="users" element={<Users />} />
        <Route path="settings" element={<Settings />} />
        <Route path="profile" element={<Profile />} />
        <Route path="*" element={<NotFound />} />
      </Route>
    </Routes>
  )
}
