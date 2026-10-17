import React from 'react'
import { BrowserRouter } from 'react-router-dom'
import { AppRoutes } from './routes/AppRoutes'
import { AuthProvider } from './context/AuthContext'
import { EmployeeProvider } from './context/EmployeeContext'

export function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <EmployeeProvider>
          <AppRoutes />
        </EmployeeProvider>
      </AuthProvider>
    </BrowserRouter>
  )
}

export default App
