---
description: Base coding rules for spa-medusa-monorepo
globs: "**/*"
alwaysApply: true
---

# Spa Medusa Monorepo - Base Cursor Rules

## Project Overview

- **Turborepo** monorepo structure with Yarn workspaces
- **Medusa.js** backend (apps/server)
- **TypeScript** based codebase
- **Docker** infrastructure for PostgreSQL and Redis

## Project Structure

```
spa-medusa-monorepo/
├── apps/
│   └── server/              # Medusa.js backend
├── packages/
│   ├── eslint-config/       # Shared ESLint configs
│   ├── typescript-config/   # Shared TypeScript configs
│   └── ui/                  # Shared UI components
├── scripts/                 # Automation scripts
└── docs/                    # Documentation
```

## Coding Style & Conventions

### Naming Conventions

- **Functions/Variables**: camelCase (`getUserData`, `isLoading`)
- **Components**: PascalCase (`Button.tsx`, `UserProfile.tsx`)
- **Constants**: UPPER_SNAKE_CASE (`API_BASE_URL`, `MAX_RETRY_COUNT`)
- **Types/Interfaces**: PascalCase (`UserRole`, `OrderStatus`)
- **Files**: kebab-case for utilities (`order-utils.ts`), PascalCase for components

### File Structure

- **Apps**: `apps/[app-name]/`
- **Packages**: `packages/[package-name]/`
- **Types**: `types/[domain].ts` or `@types/[domain].d.ts`
- **Utils**: `utils/[feature].ts` or `lib/[feature].ts`

### Import Order

```typescript
// 1. External libraries
import { MedusaRequest, MedusaResponse } from "@medusajs/medusa";
import { EntityManager } from "typeorm";

// 2. Internal packages
import { Button } from "@repo/ui/button";

// 3. Local imports
import { OrderService } from "../services";
import { formatPrice } from "../utils/price";

// 4. Types
import type { Order, OrderStatus } from "../types";
```

## TypeScript Rules

### Strict Mode Configuration

```typescript
// tsconfig.json requirements
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  }
}
```

### Type Safety

```typescript
// ✅ Correct - Explicit types
interface OrderResponse {
  id: string;
  total: number;
  status: OrderStatus;
}

async function getOrder(id: string): Promise<OrderResponse> {
  // implementation
}

// ❌ Incorrect - Using 'any'
function processData(data: any) {
  return data;
}

// ✅ Correct - Generic types
function processData<T>(data: T): T {
  return data;
}
```

### Null Safety

```typescript
// ✅ Correct - Null checks
const order = await orderRepository.findOne(id);
if (!order) {
  throw new Error("Order not found");
}
return order;

// ❌ Incorrect - No null checks
const order = await orderRepository.findOne(id);
return order.total; // Potential null reference
```

## Error Handling

### API Error Responses

```typescript
// Standard error response format
interface ErrorResponse {
  ok: false;
  error: string;
  code?: string;
  details?: unknown;
}

interface SuccessResponse<T> {
  ok: true;
  data: T;
}

type ApiResponse<T> = SuccessResponse<T> | ErrorResponse;
```

### Try-Catch Pattern

```typescript
// ✅ Correct - Comprehensive error handling
try {
  const result = await someOperation();
  return { ok: true, data: result };
} catch (error) {
  console.error("Operation failed:", {
    operation: "someOperation",
    error: error instanceof Error ? error.message : "Unknown error",
    timestamp: new Date().toISOString(),
  });

  return {
    ok: false,
    error: error instanceof Error ? error.message : "Internal server error",
  };
}
```

## Performance Optimization

### Database Queries

```typescript
// ✅ Correct - Use relations efficiently
const orders = await orderRepository.find({
  where: { customerId },
  relations: ["items", "items.variant"],
  select: ["id", "total", "status"],
});

// ❌ Incorrect - N+1 query problem
const orders = await orderRepository.find({ where: { customerId } });
for (const order of orders) {
  order.items = await itemRepository.find({ where: { orderId: order.id } });
}
```

### Caching Strategy

```typescript
// Redis caching pattern
import { RedisService } from "../services/redis";

async function getCachedData<T>(
  key: string,
  fetcher: () => Promise<T>,
  ttl: number = 3600
): Promise<T> {
  const cached = await redis.get(key);
  if (cached) {
    return JSON.parse(cached);
  }

  const data = await fetcher();
  await redis.setex(key, ttl, JSON.stringify(data));
  return data;
}
```

## Code Quality

### Function Complexity

```typescript
// ✅ Correct - Single responsibility
async function validateOrder(order: Order): Promise<ValidationResult> {
  const errors: string[] = [];

  if (!order.customerId) {
    errors.push("Customer ID is required");
  }

  if (order.items.length === 0) {
    errors.push("Order must have at least one item");
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
}

// ❌ Incorrect - Too many responsibilities
async function processOrder(order: Order) {
  // validate
  // calculate total
  // check inventory
  // create payment
  // send notification
  // All in one function - BAD!
}
```

### Code Duplication

```typescript
// ✅ Correct - Extract common logic
function calculateDiscount(price: number, discountPercent: number): number {
  return price * (discountPercent / 100);
}

const memberDiscount = calculateDiscount(total, 10);
const seasonalDiscount = calculateDiscount(total, 15);

// ❌ Incorrect - Duplicated logic
const memberDiscount = total * (10 / 100);
const seasonalDiscount = total * (15 / 100);
```

## Testing Strategy

### Unit Testing

```typescript
// Test file naming: [filename].spec.ts or [filename].test.ts
import { describe, it, expect } from "jest";
import { calculateTotal } from "./order-utils";

describe("calculateTotal", () => {
  it("should calculate total with tax", () => {
    const result = calculateTotal(100, 0.1);
    expect(result).toBe(110);
  });

  it("should handle zero tax rate", () => {
    const result = calculateTotal(100, 0);
    expect(result).toBe(100);
  });

  it("should throw error for negative prices", () => {
    expect(() => calculateTotal(-100, 0.1)).toThrow();
  });
});
```

### Integration Testing

```typescript
// Integration tests for API endpoints
describe("POST /admin/orders", () => {
  it("should create order successfully", async () => {
    const response = await request(app)
      .post("/admin/orders")
      .send({
        customerId: "cust_123",
        items: [{ variantId: "var_123", quantity: 2 }],
      })
      .expect(200);

    expect(response.body.ok).toBe(true);
    expect(response.body.data).toHaveProperty("id");
  });
});
```

## Security Best Practices

### Input Validation

```typescript
// ✅ Correct - Validate all inputs
import { z } from "zod";

const CreateOrderSchema = z.object({
  customerId: z.string().uuid(),
  items: z.array(
    z.object({
      variantId: z.string(),
      quantity: z.number().positive().int(),
    })
  ).min(1),
});

async function createOrder(req: MedusaRequest, res: MedusaResponse) {
  const validatedData = CreateOrderSchema.parse(req.body);
  // Process validated data
}
```

### Environment Variables

```typescript
// ✅ Correct - Validate required env vars
const requiredEnvVars = [
  "DATABASE_URL",
  "REDIS_URL",
  "JWT_SECRET",
] as const;

requiredEnvVars.forEach((envVar) => {
  if (!process.env[envVar]) {
    throw new Error(`Missing required environment variable: ${envVar}`);
  }
});
```

## Prohibited Practices

### No Console.log in Production

```typescript
// ❌ Incorrect
console.log("User data:", userData);

// ✅ Correct - Use proper logging
import { Logger } from "../services/logger";

logger.info("User data fetched", {
  userId: userData.id,
  // Don't log sensitive data
});
```

### No Hardcoded Values

```typescript
// ❌ Incorrect
const MAX_ITEMS = 100;
const API_URL = "https://api.example.com";

// ✅ Correct - Use config
import { config } from "../config";

const MAX_ITEMS = config.order.maxItems;
const API_URL = config.api.baseUrl;
```

### No Direct Database Access

```typescript
// ❌ Incorrect
import { dataSource } from "../database";
const users = await dataSource.query("SELECT * FROM users");

// ✅ Correct - Use repositories or services
const users = await userRepository.find();
```

## Documentation

### JSDoc Comments

```typescript
/**
 * Calculate the total price including tax and discounts
 * @param subtotal - The subtotal before tax and discounts
 * @param taxRate - Tax rate as decimal (e.g., 0.1 for 10%)
 * @param discountAmount - Fixed discount amount
 * @returns The final total price
 * @throws {Error} If subtotal is negative
 */
function calculateTotal(
  subtotal: number,
  taxRate: number,
  discountAmount: number = 0
): number {
  if (subtotal < 0) {
    throw new Error("Subtotal cannot be negative");
  }

  const tax = subtotal * taxRate;
  return subtotal + tax - discountAmount;
}
```

## Code Review Checklist

Before marking any task as complete:

1. ✅ TypeScript types are properly defined
2. ✅ No `any` types used
3. ✅ Error handling implemented
4. ✅ Input validation added
5. ✅ Tests written and passing
6. ✅ No console.log statements
7. ✅ Proper documentation added
8. ✅ No code duplication
9. ✅ Performance considerations addressed
10. ✅ Security best practices followed

## Environment-Specific Rules

### Development

- Hot reload should work without issues
- Detailed error messages are acceptable
- Debug logging is allowed

### Production

- No debug logs
- Error messages should be generic
- Performance monitoring enabled
- Rate limiting implemented
