package com.fse.banking.account.exception;

import com.fse.banking.common.dto.InvalidParam;
import com.fse.banking.common.dto.ProblemDetails;
import com.fse.banking.common.exception.BankingException;
import com.fse.banking.common.exception.ValidationException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @Autowired(required = false)
    private io.micrometer.tracing.Tracer tracer;

    private String resolveTraceId(HttpServletRequest request) {
        if (tracer != null && tracer.currentSpan() != null && tracer.currentSpan().context() != null) {
            String traceId = tracer.currentSpan().context().traceId();
            if (traceId != null && !traceId.isBlank()) {
                return traceId;
            }
        }
        String mdcTraceId = org.slf4j.MDC.get("traceId");
        if (mdcTraceId != null && !mdcTraceId.isBlank()) {
            return mdcTraceId;
        }
        Object attr = request.getAttribute("com.fse.banking.traceId");
        if (attr != null) {
            return attr.toString();
        }
        return null;
    }

    @ExceptionHandler(BankingException.class)
    public ResponseEntity<ProblemDetails> handleBankingException(BankingException ex, HttpServletRequest request) {
        log.warn("Banking business exception: status={}, errorType={}, detail={}",
                ex.getStatus(), ex.getErrorType(), ex.getMessage());

        List<InvalidParam> invalidParams = null;
        if (ex instanceof ValidationException valEx) {
            invalidParams = valEx.getInvalidParams();
        }

        ProblemDetails details = ProblemDetails.builder()
                .type(ex.getErrorType())
                .title(ex.getTitle())
                .status(ex.getStatus())
                .detail(ex.getMessage())
                .instance(request.getRequestURI())
                .timestamp(Instant.now())
                .invalidParams(invalidParams)
                .traceId(resolveTraceId(request))
                .build();

        return ResponseEntity.status(ex.getStatus()).body(details);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ProblemDetails> handleValidationException(MethodArgumentNotValidException ex, HttpServletRequest request) {
        List<InvalidParam> invalidParams = new ArrayList<>();
        for (FieldError fieldError : ex.getBindingResult().getFieldErrors()) {
            invalidParams.add(InvalidParam.builder()
                    .field(fieldError.getField())
                    // Never echo a rejected password back to the client.
                    .rejectedValue("password".equals(fieldError.getField()) ? null : fieldError.getRejectedValue())
                    .reason(fieldError.getDefaultMessage())
                    .build());
        }

        ProblemDetails details = ProblemDetails.builder()
                .type("https://api.banking.capstone/errors/validation-failed")
                .title("Bad Request")
                .status(HttpStatus.BAD_REQUEST.value())
                .detail("The payload failed JSR-380 perimeter validation constraints.")
                .instance(request.getRequestURI())
                .timestamp(Instant.now())
                .invalidParams(invalidParams)
                .traceId(resolveTraceId(request))
                .build();

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(details);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ProblemDetails> handleConstraintViolation(ConstraintViolationException ex, HttpServletRequest request) {
        List<InvalidParam> invalidParams = new ArrayList<>();
        for (ConstraintViolation<?> violation : ex.getConstraintViolations()) {
            invalidParams.add(InvalidParam.builder()
                    .field(violation.getPropertyPath().toString())
                    .rejectedValue(violation.getInvalidValue())
                    .reason(violation.getMessage())
                    .build());
        }

        ProblemDetails details = ProblemDetails.builder()
                .type("https://api.banking.capstone/errors/validation-failed")
                .title("Bad Request")
                .status(HttpStatus.BAD_REQUEST.value())
                .detail("The request parameter failed validation constraints.")
                .instance(request.getRequestURI())
                .timestamp(Instant.now())
                .invalidParams(invalidParams)
                .traceId(resolveTraceId(request))
                .build();

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(details);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ProblemDetails> handleUnreadableMessage(HttpMessageNotReadableException ex, HttpServletRequest request) {
        ProblemDetails details = ProblemDetails.builder()
                .type("https://api.banking.capstone/errors/malformed-json")
                .title("Bad Request")
                .status(HttpStatus.BAD_REQUEST.value())
                .detail("Malformed JSON or invalid request payload: " + ex.getMessage())
                .instance(request.getRequestURI())
                .timestamp(Instant.now())
                .traceId(resolveTraceId(request))
                .build();

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(details);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ProblemDetails> handleUnhandledException(Exception ex, HttpServletRequest request) {
        log.error("Unhandled internal server exception: ", ex);

        ProblemDetails details = ProblemDetails.builder()
                .type("https://api.banking.capstone/errors/internal-server-error")
                .title("Internal Server Error")
                .status(HttpStatus.INTERNAL_SERVER_ERROR.value())
                .detail("An unexpected error occurred processing your request.")
                .instance(request.getRequestURI())
                .timestamp(Instant.now())
                .traceId(resolveTraceId(request))
                .build();

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(details);
    }
}
