# Zyppi Ride - Admin Panel Requirements Document

## Executive Summary

This document outlines the comprehensive requirements for building an Admin Panel to manage the Zyppi Ride platform. The admin panel will provide centralized control over users, vehicles, bookings, content management, and platform analytics.

---

## 1. Firebase Database Structure Analysis

### 1.1 Collections Overview

| Collection | Purpose | Key Fields |
|------------|---------|------------|
| `users` | User profiles (all roles) | uid, email, phone, role, name, profileImageUrl, createdAt |
| `vehicles` | Registered vehicles | vehicleId, ownerId, type, make, model, registrationNumber, status |
| `bookings` | Trip bookings | bookingId, userId, vehicleId, driverId, status, fare, timestamps |
| `vehicleCatalog` | Vehicle catalog/inventory | make, model, type, year, specifications |
| `banners` | Promotional banners | imageUrl, title, isActive, order, targetUrl |
| `offers` | Discount offers | code, discount, validFrom, validTo, terms |
| `offer_banners` | Offer promotional images | imageUrl, offerId, isActive |
| `agreements` | Driver/Owner agreements | userId, agreementType, signedAt, version |
| `complaints` | User complaints | complaintId, userId, bookingId, description, status |
| `feedbacks` | User feedback/ratings | feedbackId, userId, bookingId, rating, comment |

### 1.2 Subcollections

- `users/{uid}/vehicles` - Vehicles owned by user
- `users/{uid}/documents` - KYC/verification documents
- `users/{uid}/earnings` - Driver earnings records
- `vehicles/{vehicleId}/availability` - Vehicle availability schedule

---

## 2. Admin Panel Modules

### 2.1 Dashboard (Home)

**Purpose:** Provide at-a-glance overview of platform metrics

**Features:**
- Total registered users (breakdown by role: User/Driver/Owner)
- Total vehicles registered
- Active bookings count
- Today's revenue
- Recent activity feed
- Quick action buttons
- Real-time metrics charts

**Firebase Queries Required:**
```javascript
// User counts
db.collection('users').where('role', '==', 'user').count()
db.collection('users').where('role', '==', 'driver').count()
db.collection('users').where('role', '==', 'owner').count()

// Today's bookings
db.collection('bookings')
  .where('createdAt', '>=', todayStart)
  .where('createdAt', '<=', todayEnd)
```

---

### 2.2 User Management

**Purpose:** Manage all platform users

#### 2.2.1 User List
- Paginated table with search & filters
- Filter by: Role, Status, Registration Date, Verification Status
- Export to CSV/Excel

#### 2.2.2 User Details
- Profile information
- Verification documents
- Activity history
- Bookings history
- Complaints/Feedback

#### 2.2.3 User Actions
- Approve/Reject verification
- Suspend/Ban user
- Reset password
- Send notification
- View/Edit profile
- Delete account

**Data Model:**
```dart
class AdminUser {
  String uid;
  String email;
  String phone;
  String name;
  String role; // 'user', 'driver', 'owner'
  String status; // 'active', 'suspended', 'banned'
  bool isVerified;
  DateTime createdAt;
  String? profileImageUrl;
  Map<String, dynamic>? documents;
}
```

---

### 2.3 Vehicle Management

**Purpose:** Manage all registered vehicles

#### 2.3.1 Vehicle List
- All vehicles with pagination
- Filter by: Type, Status, Owner, Availability
- Search by registration number, make, model

#### 2.3.2 Vehicle Details
- Full specifications
- Owner information
- Assigned driver
- Booking history
- Availability calendar
- Documents (RC, Insurance, PUC)

#### 2.3.3 Vehicle Actions
- Approve/Reject registration
- Update status (active/inactive/maintenance)
- Assign/Remove driver
- View documents
- Delete vehicle

**Vehicle Types Supported:**
- Bike (2-wheeler)
- Auto Rickshaw (3-wheeler)
- Car - Sedan
- Car - SUV
- Car - Hatchback
- Van
- Minibus

---

### 2.4 Booking Management

**Purpose:** Monitor and manage all bookings

#### 2.4.1 Booking List
- Real-time booking feed
- Filter by: Status, Date Range, Vehicle Type, Payment Status
- Search by booking ID, user, driver

#### 2.4.2 Booking Status Types
- `pending` - Booking created, awaiting driver
- `accepted` - Driver accepted
- `in_progress` - Trip ongoing
- `completed` - Trip finished
- `cancelled` - Cancelled by user/driver
- `disputed` - Under dispute resolution

#### 2.4.3 Booking Actions
- View full details
- Cancel booking
- Initiate refund
- Resolve disputes
- Contact user/driver
- Export booking data

---

### 2.5 Content Management

#### 2.5.1 Banner Management
- Add/Edit/Delete promotional banners
- Set banner order/priority
- Schedule banner visibility
- Link banners to offers/screens

**Banner Schema:**
```javascript
{
  id: string,
  imageUrl: string,
  title: string,
  subtitle: string,
  targetType: 'offer' | 'screen' | 'url',
  targetValue: string,
  isActive: boolean,
  order: number,
  validFrom: timestamp,
  validTo: timestamp
}
```

#### 2.5.2 Offer Management
- Create discount offers
- Set offer codes
- Define validity period
- Set usage limits
- Target specific user segments

**Offer Schema:**
```javascript
{
  id: string,
  code: string,
  title: string,
  description: string,
  discountType: 'percentage' | 'flat',
  discountValue: number,
  minBookingAmount: number,
  maxDiscount: number,
  validFrom: timestamp,
  validTo: timestamp,
  usageLimit: number,
  usedCount: number,
  isActive: boolean,
  targetUserType: 'all' | 'new' | 'existing'
}
```

#### 2.5.3 Vehicle Catalog
- Manage vehicle makes/models
- Add new vehicle types
- Set default pricing
- Upload vehicle images

---

### 2.6 Complaints & Support

#### 2.6.1 Complaint Management
- View all complaints
- Filter by: Status, Priority, Category
- Assign to support staff
- Track resolution time

#### 2.6.2 Complaint Status
- `open` - New complaint
- `in_progress` - Being investigated
- `resolved` - Issue fixed
- `closed` - Closed without action

#### 2.6.3 Complaint Actions
- View complaint details
- View related booking
- Contact parties involved
- Update status
- Add internal notes
- Escalate to higher authority

---

### 2.7 Feedback & Ratings

- View all feedback
- Filter by rating (1-5 stars)
- Identify low-rated drivers/vehicles
- Export feedback reports
- Respond to feedback

---

### 2.8 Agreement Management

- Manage legal agreements (Terms, Privacy Policy)
- Track user agreement signatures
- Version control for agreements
- Force re-acceptance on updates

---

### 2.9 Reports & Analytics

#### 2.9.1 Revenue Reports
- Daily/Weekly/Monthly revenue
- Revenue by vehicle type
- Revenue by region
- Payment method breakdown
- Commission earned

#### 2.9.2 User Reports
- User growth trends
- User retention metrics
- Active vs inactive users
- User acquisition channels

#### 2.9.3 Booking Reports
- Booking trends
- Peak hours analysis
- Popular routes
- Cancellation rates
- Average trip duration/distance

#### 2.9.4 Driver Reports
- Driver performance metrics
- Earnings distribution
- Online hours
- Trip completion rate
- Average rating

---

### 2.10 Settings & Configuration

#### 2.10.1 Platform Settings
- Commission rates
- Minimum fare
- Base fare configuration
- Per km/minute rates
- Surge pricing rules

#### 2.10.2 Notification Templates
- Push notification templates
- SMS templates
- Email templates

#### 2.10.3 Admin Users
- Create admin accounts
- Define roles & permissions
- Activity logs

---

## 3. Admin Roles & Permissions

| Role | Dashboard | Users | Vehicles | Bookings | Content | Reports | Settings |
|------|-----------|-------|----------|----------|---------|---------|----------|
| Super Admin | Full | Full | Full | Full | Full | Full | Full |
| Admin | View | Full | Full | Full | Full | View | View |
| Support | View | View | View | Full | None | None | None |
| Content Manager | View | None | None | None | Full | None | None |
| Analyst | View | View | View | View | None | Full | None |

---

## 4. Technical Recommendations

### 4.1 Technology Stack
- **Frontend:** React.js / Next.js with TypeScript
- **UI Library:** Material-UI or Ant Design
- **State Management:** Redux Toolkit or Zustand
- **Backend:** Firebase Admin SDK (Node.js)
- **Database:** Firestore (existing)
- **Authentication:** Firebase Auth with custom claims
- **Hosting:** Firebase Hosting or Vercel

### 4.2 Security Considerations
- Role-based access control (RBAC)
- Audit logging for all actions
- Two-factor authentication for admins
- IP whitelisting for admin access
- Encrypted sensitive data
- Regular security audits

### 4.3 Firebase Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Admin-only access
    function isAdmin() {
      return request.auth != null &&
        get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.role in ['admin', 'super_admin'];
    }

    match /users/{userId} {
      allow read: if isAdmin();
      allow write: if isAdmin();
    }

    // ... more rules
  }
}
```

---

## 5. Implementation Phases

### Phase 1: Core Admin (4-6 weeks)
- Dashboard with basic metrics
- User management (CRUD)
- Vehicle management (CRUD)
- Basic authentication

### Phase 2: Operations (3-4 weeks)
- Booking management
- Complaint handling
- Feedback management
- Real-time updates

### Phase 3: Content & Marketing (2-3 weeks)
- Banner management
- Offer/Coupon system
- Push notifications
- Vehicle catalog

### Phase 4: Analytics & Reports (3-4 weeks)
- Revenue reports
- User analytics
- Booking analytics
- Export functionality

### Phase 5: Advanced Features (2-3 weeks)
- Role-based permissions
- Audit logs
- Advanced search
- Bulk operations

---

## 6. API Endpoints (Firebase Functions)

```javascript
// User Management
POST   /api/admin/users              - Create user
GET    /api/admin/users              - List users
GET    /api/admin/users/:id          - Get user details
PUT    /api/admin/users/:id          - Update user
DELETE /api/admin/users/:id          - Delete user
POST   /api/admin/users/:id/verify   - Verify user
POST   /api/admin/users/:id/suspend  - Suspend user

// Vehicle Management
POST   /api/admin/vehicles           - Add vehicle
GET    /api/admin/vehicles           - List vehicles
PUT    /api/admin/vehicles/:id       - Update vehicle
DELETE /api/admin/vehicles/:id       - Delete vehicle
POST   /api/admin/vehicles/:id/approve - Approve vehicle

// Booking Management
GET    /api/admin/bookings           - List bookings
GET    /api/admin/bookings/:id       - Get booking details
PUT    /api/admin/bookings/:id       - Update booking
POST   /api/admin/bookings/:id/cancel - Cancel booking
POST   /api/admin/bookings/:id/refund - Process refund

// Content Management
POST   /api/admin/banners            - Create banner
PUT    /api/admin/banners/:id        - Update banner
DELETE /api/admin/banners/:id        - Delete banner
POST   /api/admin/offers             - Create offer
PUT    /api/admin/offers/:id         - Update offer

// Reports
GET    /api/admin/reports/revenue    - Revenue report
GET    /api/admin/reports/users      - User metrics
GET    /api/admin/reports/bookings   - Booking stats
```

---

## 7. Database Indexes Required

```javascript
// Firestore Composite Indexes
users: [role, createdAt]
users: [status, role]
vehicles: [ownerId, status]
vehicles: [type, status]
bookings: [status, createdAt]
bookings: [userId, createdAt]
bookings: [driverId, status]
complaints: [status, createdAt]
feedbacks: [rating, createdAt]
```

---

## 8. Estimated Resources

| Resource | Quantity | Notes |
|----------|----------|-------|
| Frontend Developer | 1-2 | React/Next.js experience |
| Backend Developer | 1 | Firebase/Node.js experience |
| UI/UX Designer | 1 | Admin dashboard experience |
| QA Engineer | 1 | Manual + automation testing |
| Project Manager | 1 | Part-time |

**Timeline:** 12-16 weeks for full implementation
**Budget:** Varies based on team location and rates

---

*Document Version: 1.0*
*Last Updated: February 2026*
*Prepared for: Zyppi Ride Platform*
