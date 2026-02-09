import { NavLink, Outlet } from 'react-router-dom';
import '../styles/theme.css';

const navItems = [
  { icon: 'home', label: 'Home', path: '/' },
  { icon: 'auto_awesome', label: 'Create', path: '/create' },
  { icon: 'account_tree', label: 'Pipeline', path: '/pipelines' },
  { icon: 'folder', label: 'Assets', path: '/assets' },
];

const bottomItems = [
  { icon: 'monitor_heart', label: 'Status', path: '/status' },
  { icon: 'settings', label: 'Settings', path: '/settings' },
];

export default function Layout() {
  return (
    <div className="layout-shell">
      <nav className="sidebar-nav">
        <div className="sidebar-logo">O</div>
        <div className="sidebar-items">
          {navItems.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              end={item.path === '/'}
              className={({ isActive }) =>
                `sidebar-item${isActive ? ' active' : ''}`
              }
              data-tooltip={item.label}
            >
              <span className="material-icons">{item.icon}</span>
            </NavLink>
          ))}
          <div className="sidebar-divider" />
          {bottomItems.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              className={({ isActive }) =>
                `sidebar-item${isActive ? ' active' : ''}`
              }
              data-tooltip={item.label}
            >
              <span className="material-icons">{item.icon}</span>
            </NavLink>
          ))}
        </div>
      </nav>
      <div className="page-content">
        <Outlet />
      </div>
    </div>
  );
}
