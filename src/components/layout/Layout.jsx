import React, { useState } from 'react'
import { Outlet } from 'react-router-dom'
import { Sidebar } from './Sidebar'
import { Header } from './Header'
import { Modal } from '../common/Modal'
import { Button } from '../common/Button'
import { LogOut } from 'lucide-react'

/**
 * Master Dashboard Layout Shell
 */
export function Layout() {
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const [logoutModalOpen, setLogoutModalOpen] = useState(false)

  const handleConfirmLogout = () => {
    // Clean mock logout action for step 1
    setLogoutModalOpen(false)
    alert('Logout triggered. Auth state will be managed in upcoming authentication step.')
  }

  return (
    <div className="min-h-screen bg-slate-50 flex flex-row antialiased text-slate-900">
      {/* Left Sidebar */}
      <Sidebar
        isOpen={sidebarOpen}
        onClose={() => setSidebarOpen(false)}
        onLogoutClick={() => setLogoutModalOpen(true)}
      />

      {/* Main Content Column */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Top Header */}
        <Header
          onToggleSidebar={() => setSidebarOpen((prev) => !prev)}
          onLogoutClick={() => setLogoutModalOpen(true)}
        />

        {/* Content Outlet */}
        <main className="flex-1 p-4 sm:p-6 lg:p-8 max-w-7xl w-full mx-auto">
          <Outlet />
        </main>
      </div>

      {/* Logout Confirmation Modal */}
      <Modal
        isOpen={logoutModalOpen}
        onClose={() => setLogoutModalOpen(false)}
        title="Confirm Sign Out"
        description="Are you sure you want to sign out of the Food Safety Management System?"
        footer={
          <>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => setLogoutModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              variant="danger"
              size="sm"
              icon={LogOut}
              onClick={handleConfirmLogout}
            >
              Sign Out
            </Button>
          </>
        }
      >
        <p className="text-sm text-slate-600">
          You will need to authenticate again to access inspection reports, audit logs, and CAPA actions.
        </p>
      </Modal>
    </div>
  )
}
