import { LoginTokenPayload } from "./aut./auth.types.ts

declare global {
  namespace Express {
    interface Request {
      user?: LoginTokenPayload;
    }
  }
}
