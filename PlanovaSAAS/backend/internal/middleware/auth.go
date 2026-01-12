package middleware

import (
	"net/http"

	"github.com/labstack/echo/v4"
	"github.com/planovasaas/backend/internal/database"
)

func AuthRequired(db *database.DB) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			userId := c.Get("userId")
			if userId == nil || userId == "" {
				return c.HTML(http.StatusUnauthorized, `<html><body>Please login first</body></html>`)
			}
			return next(c)
		}
	}
}

func CORS() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			c.Response().Header().Set("Access-Control-Allow-Origin", "*")
			c.Response().Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			c.Response().Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
			c.Response().Header().Set("Access-Control-Allow-Credentials", "true")

			if c.Request().Method == http.MethodOptions {
				return c.NoContent(http.StatusNoContent)
			}

			return next(c)
		}
	}
}

func CSRF() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			token := c.Request().Header.Get("X-CSRF-Token")
			if token == "" {
				token = c.QueryParam("csrf_token")
			}
			c.Set("csrf_token", token)
			return next(c)
		}
	}
}
